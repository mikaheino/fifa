/*
USE DATABASE COALESCE_DEV ;
USE SCHEMA FIFA_PREDICTION ;
CREATE OR REPLACE TABLE RESULTS CLONE COALESCE_DEV.STG.STG_FIFA_RESULTS ; 
CREATE OR REPLACE TABLE FIFA_SCHEDULE CLONE COALESCE_DEV.STG.FIFA_SCHEDULE ; 

SELECT * FROM COALESCE_DEV.FIFA_PREDICTION.RESULTS ; 
SELECT * FROM COALESCE_DEV.FIFA_PREDICTION.FIFA_SCHEDULE ; 

*/

/* 
1. In the training data United States is used instead 
   of USA and same applies for South Korea. 
   Let's also empty the table from any previous predictions.
   
UPDATE FIFA_SCHEDULE
SET HOME_TEAM = 'United States' WHERE HOME_TEAM = 'USA' ; 

UPDATE FIFA_SCHEDULE
SET AWAY_TEAM = 'United States' WHERE AWAY_TEAM = 'USA' ; 

UPDATE FIFA_SCHEDULE
SET HOME_TEAM = 'South Korea' WHERE HOME_TEAM = 'Korea Republic' ; 

UPDATE FIFA_SCHEDULE
SET AWAY_TEAM = 'South Korea' WHERE AWAY_TEAM = 'Korea Republic' ; 

UPDATE COALESCE_DEV.FIFA_PREDICTION.FIFA_SCHEDULE
SET PREDICT_FOR_HOME_WIN = 'NULL' ;

*/

/* 2. Predict 1st round winners using existing FIFA_SCHEDULE
      Loop through the schedule and populate PREDICT_FOR_HOME_WIN column with
	  value provided by previously build FUNCTION
      
      Note, this can take up to 20minutes with X-SMALL warehouse
      
DECLARE
    c1 CURSOR FOR SELECT home_team, away_team FROM FIFA_SCHEDULE WHERE length(BRACKET_GROUP) > 1;
     
    home_team VARCHAR;
    away_team VARCHAR;
BEGIN
  FOR record IN c1 DO
      home_team := record.home_team;
      away_team := record.away_team;
      
      UPDATE FIFA_SCHEDULE f SET predict_for_home_win = prediction.p 
      FROM (SELECT predict_result(:home_team, :away_team) p ) AS prediction
      WHERE f.home_team = :home_team AND f.away_team = :away_team ;
      
  END FOR;
END;
*/

/*
-- 3. Create view to show winners of Group stage
CREATE OR REPLACE VIEW COALESCE_DEV.FIFA_PREDICTION.A1_WINNERS_GROUP_STAGE(
	HOME_TEAM,
	AWAY_TEAM,
	WINNER
) as (
SELECT 
        HOME_TEAM
      , AWAY_TEAM
      , CASE WHEN PREDICT_FOR_HOME_WIN > 0.5 THEN HOME_TEAM
        ELSE AWAY_TEAM END AS WINNER
FROM FIFA_SCHEDULE WHERE length(BRACKET_GROUP) > 1
);
*/

/*
-- 4. Create view to show Round of 16 game pairs
CREATE OR REPLACE VIEW COALESCE_DEV.FIFA_PREDICTION.A2_GAME_PAIRS_ROUND_OF_16(
	HOME_TEAM,
	AWAY_TEAM,
	MATCH
) as (
WITH BRACKET_WINNERS AS (
SELECT 
      DISTINCT
      winners_group_stage.HOME_TEAM as W_HOME,
      winners_group_stage.AWAY_TEAM as W_AWAY,
      fifa_schedule.BRACKET_GROUP,
      winners_group_stage.WINNER
FROM A1_WINNERS_GROUP_STAGE winners_group_stage
INNER JOIN FIFA_SCHEDULE fifa_schedule ON TRIM(fifa_schedule.HOME_TEAM) = TRIM(winners_group_stage.HOME_TEAM) AND TRIM(fifa_schedule.AWAY_TEAM) = TRIM(winners_group_stage.AWAY_TEAM)
 GROUP BY BRACKET_GROUP, W_HOME, W_AWAY, WINNER
 ORDER BY BRACKET_GROUP asc 
), BRACKET_QUALIFIERS AS (
    SELECT 
         TRIM(BRACKET_GROUP) AS BRACKET_GROUP,
         WINNER,
         COUNT(WINNER) AS WIN_COUNT,
         RANK() OVER (PARTITION BY BRACKET_GROUP ORDER BY COUNT(WINNER) DESC) AS rank 
    FROM BRACKET_WINNERS
    GROUP BY BRACKET_GROUP, WINNER
), BRACKET_RANKS AS (
   SELECT 
          bracket_qualifiers.BRACKET_GROUP
        , bracket_qualifiers.WINNER AS COUNTRY
        , bracket_qualifiers.WIN_COUNT AS WINS
        , CASE WHEN rank = 1 THEN
               1 || LTRIM(BRACKET_GROUP, 'Group')
          ELSE 2 || LTRIM(BRACKET_GROUP, 'Group')
         END AS RANK_IN_BRACKET
   FROM BRACKET_QUALIFIERS bracket_qualifiers
 WHERE RANK < 3
), BRACKET_RANK_TO_COUNTRY_SCHEDULE AS (
   SELECT 
         COUNTRY
       , REPLACE(RANK_IN_BRACKET, ' ', '') AS RANK_IN_BRACKET
   FROM BRACKET_RANKS
  ORDER BY RANK_IN_BRACKET
), KNOCKOUT_GAMES AS (SELECT 
        *
   FROM FIFA_SCHEDULE 
WHERE ROUND_NUMBER like 'Round%'
) SELECT 
         bg_home.country AS HOME_TEAM
       , bg_away.country AS AWAY_TEAM
       , match
    FROM KNOCKOUT_GAMES kg 
    INNER JOIN BRACKET_RANK_TO_COUNTRY_SCHEDULE bg_home ON bg_home.RANK_IN_BRACKET = kg.HOME_TEAM
    INNER JOIN BRACKET_RANK_TO_COUNTRY_SCHEDULE bg_away ON bg_away.RANK_IN_BRACKET = kg.AWAY_TEAM
) ;
*/

-- 5. Create table where to store Round of 16 game results
/*
CREATE OR REPLACE TABLE COALESCE_DEV.FIFA_PREDICTION.A3_WINNERS_ROUND_OF_16 (
    HOME_TEAM VARCHAR(16777216),
    AWAY_TEAM VARCHAR(16777216),
    PREDICT_FOR_HOME_WIN FLOAT
);
*/
/*
-- 6. Populate table with game pairs for Round 16
INSERT INTO A3_WINNERS_ROUND_OF_16 (HOME_TEAM, AWAY_TEAM)
SELECT HOME_TEAM, AWAY_TEAM FROM A2_GAME_PAIRS_ROUND_OF_16 ; 
*/


/*
-- 7. Predict Round of 16 games      
      Note, this takes approx 2,5 mins with X-SMALL warehouse
      
DECLARE
    c1 CURSOR FOR SELECT home_team, away_team FROM A3_WINNERS_ROUND_OF_16 ;
     
    home_team VARCHAR;
    away_team VARCHAR;
BEGIN
  FOR record IN c1 DO
      home_team := record.home_team;
      away_team := record.away_team;
      
      UPDATE A3_WINNERS_ROUND_OF_16 f SET predict_for_home_win = prediction.p 
      FROM (SELECT predict_result(:home_team, :away_team) p ) AS prediction
      WHERE f.home_team = :home_team AND f.away_team = :away_team ;
      
  END FOR;
END;
*/
/*
-- 8. List Round of 16 game winners
CREATE OR REPLACE VIEW COALESCE_DEV.FIFA_PREDICTION.A4_WINNERS_ROUND_OF_16(
	HOME_TEAM,
	AWAY_TEAM,
	WINNER
) as (
SELECT 
        HOME_TEAM
      , AWAY_TEAM
      , CASE WHEN PREDICT_FOR_HOME_WIN > 0.5 THEN HOME_TEAM
        ELSE AWAY_TEAM END AS WINNER
FROM COALESCE_DEV.FIFA_PREDICTION.A3_WINNERS_ROUND_OF_16 );
*/
/*
-- 9. Create view to show Quarter final game pairs
CREATE OR REPLACE VIEW COALESCE_DEV.FIFA_PREDICTION.A5_GAME_PAIRS_QUARTER_FINALS (
	HOME_TEAM,
	AWAY_TEAM,
	MATCH
) as (
WITH KNOCKOUT_WINNERS AS (
SELECT 
        winners_round_of_16.winner
      , game_pairs_round_of_16.match
 FROM A4_WINNERS_ROUND_OF_16 winners_round_of_16
 INNER JOIN A2_GAME_PAIRS_ROUND_OF_16 game_pairs_round_of_16 ON TRIM(game_pairs_round_of_16.HOME_TEAM) = TRIM(winners_round_of_16.HOME_TEAM) AND TRIM(game_pairs_round_of_16.AWAY_TEAM) = TRIM(winners_round_of_16.AWAY_TEAM)
), QUARTER_FINALS_SCHEDULE AS (
 SELECT
      REPLACE(HOME_TEAM, 'Winner Match') as HOME_TEAM
    , REPLACE(AWAY_TEAM, 'Winner Match') as AWAY_TEAM
    , match
 FROM FIFA_SCHEDULE 
 WHERE MATCH BETWEEN 57 AND 60
)  SELECT
          kw1.winner AS home_team
        , kw2.winner AS away_team
        , qg.match
    FROM QUARTER_FINALS_SCHEDULE qg
    INNER JOIN KNOCKOUT_WINNERS kw1 ON TRIM(kw1.MATCH) = TRIM(qg.HOME_TEAM)
    INNER JOIN KNOCKOUT_WINNERS kw2 ON TRIM(kw2.MATCH) = TRIM(qg.AWAY_TEAM)
);
*/
/*
-- 10. Create table where to predict 3rd round winners
CREATE OR REPLACE TABLE COALESCE_DEV.FIFA_PREDICTION.A6_GAME_PAIRS_QUARTER_FINALS (
    HOME_TEAM VARCHAR(16777216),
    AWAY_TEAM VARCHAR(16777216),
    PREDICT_FOR_HOME_WIN FLOAT
);
*/

/*
-- 11. Populate Quarter final game pairs
INSERT INTO A6_GAME_PAIRS_QUARTER_FINALS (HOME_TEAM, AWAY_TEAM)
SELECT HOME_TEAM, AWAY_TEAM FROM A5_GAME_PAIRS_QUARTER_FINALS ; 
*/

/*
-- 12. Predict Quarter final winners
       Note, this takes approx 2 mins with X-SMALL warehouse
       
DECLARE
    c1 CURSOR FOR SELECT home_team, away_team FROM A6_GAME_PAIRS_QUARTER_FINALS ;
     
    home_team VARCHAR;
    away_team VARCHAR;
BEGIN
  FOR record IN c1 DO
      home_team := record.home_team;
      away_team := record.away_team;
      
      UPDATE A6_GAME_PAIRS_QUARTER_FINALS f SET predict_for_home_win = prediction.p 
      FROM (SELECT predict_result(:home_team, :away_team) p ) AS prediction
      WHERE f.home_team = :home_team AND f.away_team = :away_team ;
      
  END FOR;
END;
*/

/*
-- 13. List Quarter final round winners 
CREATE OR REPLACE VIEW COALESCE_DEV.FIFA_PREDICTION.A7_WINNERS_OF_QUARTER_FINALS (
	HOME_TEAM,
	AWAY_TEAM,
	WINNER
) as (
SELECT 
        HOME_TEAM
      , AWAY_TEAM
      , CASE WHEN PREDICT_FOR_HOME_WIN > 0.5 THEN HOME_TEAM
        ELSE AWAY_TEAM END AS WINNER
FROM A6_GAME_PAIRS_QUARTER_FINALS );
*/
/*
-- 14. Create view to show Semi final round pairs
CREATE OR REPLACE VIEW COALESCE_DEV.FIFA_PREDICTION.A8_GAME_PAIRS_SEMI_FINALS (
	HOME_TEAM,
	AWAY_TEAM,
	MATCH
) as (
WITH QF_WINNERS AS (
SELECT 
        winners_of_quarter_finals.winner
      , game_pairs_quarter_finals.match
  FROM A7_WINNERS_OF_QUARTER_FINALS winners_of_quarter_finals
 INNER JOIN A5_GAME_PAIRS_QUARTER_FINALS game_pairs_quarter_finals ON TRIM(game_pairs_quarter_finals.HOME_TEAM) = TRIM(winners_of_quarter_finals.HOME_TEAM) AND TRIM(game_pairs_quarter_finals.AWAY_TEAM) = TRIM(winners_of_quarter_finals.AWAY_TEAM)
), SEMI_FINALS_SCHEDULE AS (
 SELECT
      REPLACE(HOME_TEAM, 'Winner Match') as HOME_TEAM
    , REPLACE(AWAY_TEAM, 'Winner Match') as AWAY_TEAM
    , match
 FROM FIFA_SCHEDULE 
 WHERE MATCH BETWEEN 61 AND 62
)  SELECT
          kw1.winner AS home_team
        , kw2.winner AS away_team
        , ss.MATCH
    FROM SEMI_FINALS_SCHEDULE ss
    INNER JOIN QF_WINNERS kw1 ON TRIM(kw1.MATCH) = TRIM(ss.HOME_TEAM)
    INNER JOIN QF_WINNERS kw2 ON TRIM(kw2.MATCH) = TRIM(ss.AWAY_TEAM)
) ;
*/
/*
-- 14. Create table where to predict 4rd round winners
CREATE OR REPLACE TABLE COALESCE_DEV.FIFA_PREDICTION.A9_WINNERS_OF_SEMI_FINALS (
	HOME_TEAM VARCHAR(16777216),
	AWAY_TEAM VARCHAR(16777216),
	PREDICT_FOR_HOME_WIN FLOAT
);
*/
-- 15.
-- Populate 4rd round game pairs
/*
INSERT INTO A9_WINNERS_OF_SEMI_FINALS (HOME_TEAM, AWAY_TEAM)
SELECT HOME_TEAM, AWAY_TEAM FROM A8_GAME_PAIRS_SEMI_FINALS ; 
*/

-- 16. Predict Semi final round winners
/*
DECLARE
    c1 CURSOR FOR SELECT home_team, away_team FROM A9_WINNERS_OF_SEMI_FINALS ;
     
    home_team VARCHAR;
    away_team VARCHAR;
BEGIN
  FOR record IN c1 DO
      home_team := record.home_team;
      away_team := record.away_team;
      
      UPDATE A9_WINNERS_OF_SEMI_FINALS f SET predict_for_home_win = prediction.p 
      FROM (SELECT predict_result(:home_team, :away_team) p ) AS prediction
      WHERE f.home_team = :home_team AND f.away_team = :away_team ;
      
  END FOR;
END;
*/

/*
--17. List Semi final round winners
CREATE OR REPLACE VIEW COALESCE_DEV.FIFA_PREDICTION.A10_WINNERS_OF_SEMI_FINALS (
	HOME_TEAM,
	AWAY_TEAM,
	WINNER
) as (
SELECT 
        HOME_TEAM
      , AWAY_TEAM
      , CASE WHEN PREDICT_FOR_HOME_WIN > 0.5 THEN HOME_TEAM
        ELSE AWAY_TEAM END AS WINNER
FROM A9_WINNERS_OF_SEMI_FINALS);
*/

/*
--18. Populate final round pair
CREATE OR REPLACE VIEW COALESCE_DEV.FIFA_PREDICTION.A11_GAME_PAIR_FINAL (
	HOME_TEAM,
	AWAY_TEAM,
	MATCH
) as (
WITH QF_WINNERS AS (
SELECT 
        winners_of_semi_finals.winner
      , game_pairs_of_semi_finals.match
  FROM A10_WINNERS_OF_SEMI_FINALS winners_of_semi_finals
 INNER JOIN A8_GAME_PAIRS_SEMI_FINALS game_pairs_of_semi_finals ON TRIM(game_pairs_of_semi_finals.HOME_TEAM) = TRIM(winners_of_semi_finals.HOME_TEAM) AND TRIM(game_pairs_of_semi_finals.AWAY_TEAM) = TRIM(winners_of_semi_finals.AWAY_TEAM)
), FINALS_SCHEDULE AS (
 SELECT
      REPLACE(HOME_TEAM, 'Winner Match') as HOME_TEAM
    , REPLACE(AWAY_TEAM, 'Winner Match') as AWAY_TEAM
    , match
 FROM FIFA_SCHEDULE 
 WHERE MATCH = 64
)  SELECT
          kw1.winner AS home_team
        , kw2.winner AS away_team
        , ss.MATCH
    FROM FINALS_SCHEDULE ss
    INNER JOIN QF_WINNERS kw1 ON TRIM(kw1.MATCH) = TRIM(ss.HOME_TEAM)
    INNER JOIN QF_WINNERS kw2 ON TRIM(kw2.MATCH) = TRIM(ss.AWAY_TEAM)
) ;
*/

/*
--19. Create table to store Final result
CREATE OR REPLACE TABLE COALESCE_DEV.FIFA_PREDICTION.A12_WINNER_FINAL (
	HOME_TEAM VARCHAR(16777216),
	AWAY_TEAM VARCHAR(16777216),
	PREDICT_FOR_HOME_WIN FLOAT
);

/*
--20. Populate Final pair
INSERT INTO A12_WINNER_FINAL (HOME_TEAM, AWAY_TEAM)
SELECT HOME_TEAM, AWAY_TEAM FROM A11_GAME_PAIR_FINAL ; 
*/

/*
--21. Predict winner of FIFA World Cup
DECLARE
    c1 CURSOR FOR SELECT home_team, away_team FROM A12_WINNER_FINAL ;
     
    home_team VARCHAR;
    away_team VARCHAR;
BEGIN
  FOR record IN c1 DO
      home_team := record.home_team;
      away_team := record.away_team;
      
      UPDATE A12_WINNER_FINAL f SET predict_for_home_win = prediction.p 
      FROM (SELECT predict_result(:home_team, :away_team) p ) AS prediction
      WHERE f.home_team = :home_team AND f.away_team = :away_team ;
      
  END FOR;
END;
*/

CREATE OR REPLACE VIEW COALESCE_DEV.FIFA_PREDICTION.A13_WINNER_FINAL (
	HOME_TEAM,
	AWAY_TEAM,
	WINNER
) as (
SELECT 
        HOME_TEAM
      , AWAY_TEAM
      , CASE WHEN PREDICT_FOR_HOME_WIN > 0.5 THEN HOME_TEAM
        ELSE AWAY_TEAM END AS WINNER
FROM A12_WINNER_FINAL);

SELECT * FROM FIFA_SCHEDULE ; 
SELECT * FROM A1_WINNERS_GROUP_STAGE ; 
SELECT * FROM A2_GAME_PAIRS_ROUND_OF_16 ;
SELECT * FROM A3_WINNERS_ROUND_OF_16 ; 
SELECT * FROM A4_WINNERS_ROUND_OF_16 ; 
SELECT * FROM A5_GAME_PAIRS_QUARTER_FINALS ;
SELECT * FROM A6_GAME_PAIRS_QUARTER_FINALS ;
SELECT * FROM A7_WINNERS_OF_QUARTER_FINALS ;
SELECT * FROM A8_GAME_PAIRS_SEMI_FINALS ;
SELECT * FROM A9_WINNERS_OF_SEMI_FINALS ;
SELECT * FROM A10_WINNERS_OF_SEMI_FINALS ; 
SELECT * FROM A11_GAME_PAIR_FINAL ;
SELECT * FROM A12_WINNER_FINAL ;
SELECT * FROM A13_WINNER_FINAL ;


