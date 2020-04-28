-- Persistent generated migration.

CREATE FUNCTION migrate() RETURNS void AS $$
DECLARE
  next_version int ;
BEGIN
  SELECT stage_two + 1 INTO next_version FROM schema_version ;
  IF next_version = 8 THEN
    EXECUTE 'ALTER TABLE "meta" ADD COLUMN "network_name" VARCHAR' ;
    -- Hand written SQL statements can be added here.
    UPDATE schema_version SET stage_two = 8 ;
    RAISE NOTICE 'DB has been migrated to stage_two version %', next_version ;
  END IF ;
END ;
$$ LANGUAGE plpgsql ;

SELECT migrate() ;

DROP FUNCTION migrate() ;
