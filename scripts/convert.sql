USE ITIS;

DROP DATABASE IF EXISTS coldp;
CREATE DATABASE coldp DEFAULT CHARSET utf8mb4 COLLATE utf8mb4_general_ci;


# Create an extinct table in ITIS database
DROP TABLE IF EXISTS extinct;
CREATE TABLE extinct (
    SELECT tu.tsn AS tsn,
           complete_name,
           comment_detail AS extinct_comment,
           IF(LOWER(comment_detail) = 'extinct', true, false) AS extinct
    FROM taxonomic_units tu
             INNER JOIN tu_comments_links tcl ON tu.tsn = tcl.tsn
             INNER JOIN comments c ON c.comment_id = tcl.comment_id
    WHERE LOWER(comment_detail) LIKE '%extinct%'
);
CREATE INDEX extinct_tsn_index
	ON extinct (tsn);


# TODO: Provisional
# Taxon
DROP TABLE IF EXISTS coldp.Taxon;
CREATE TABLE coldp.Taxon (
    SELECT h.TSN AS ID,
           h.Parent_TSN AS parentID,
           h.TSN AS nameID,
           FALSE AS provisional,
           (SELECT DISTINCT GROUP_CONCAT(expert SEPARATOR ', ') FROM reference_links rl INNER JOIN experts ON rl.documentation_id=experts.expert_id AND rl.doc_id_prefix='EXP' WHERE rl.tsn=h.TSN) AS accordingTo,
           NULL AS accordingToID,
           tu.update_date AS accordingToDate,
           (SELECT DISTINCT GROUP_CONCAT(documentation_id SEPARATOR ', ') FROM reference_links rl WHERE rl.tsn=h.TSN AND doc_id_prefix='PUB') AS referenceID,
           IF(extinct IS NULL, 0, extinct) AS extinct,
           IF (LOWER(extinct_comment) = 'extinct', NULL, extinct_comment) AS remarks  # add other extinct comment
    FROM hierarchy h
        LEFT JOIN taxonomic_units tu ON h.TSN = tu.tsn
        LEFT JOIN extinct ext ON tu.tsn = ext.tsn
);
CREATE INDEX taxon_id
	ON coldp.Taxon (ID);
CREATE INDEX parent_id
	ON coldp.Taxon (parentID);
CREATE INDEX name_id
	ON coldp.Taxon (nameID);


#SELECT tsn, expert FROM experts INNER JOIN reference_links rl ON experts.expert_id = rl.documentation_id AND experts.expert_id_prefix = rl.doc_id_prefix GROUP BY tsn HAVING count(*) > 1;

#SELECT DISTINCT tu.kingdom_id, kingdom_name, name_usage, unaccept_reason FROM taxonomic_units tu LEFT JOIN kingdoms ON tu.kingdom_id = kingdoms.kingdom_id ORDER BY kingdom_name, unaccept_reason;
#SELECT DISTINCT n_usage, kingdom_id FROM taxonomic_units;
#SELECT DISTINCT name_usage FROM taxonomic_units;

# TODO: Hybrid formulas: complete_name has hybrid formula markers included, but need to check if CoL+ handles it correctly
# TODO: Nom original
# Name
DROP TABLE IF EXISTS coldp.Name;
CREATE TABLE coldp.Name (
    SELECT TSN AS ID,
           complete_name AS scientificName,
           tal.taxon_author AS authorship,
           LOWER(tut.rank_name) AS `rank`,
           complete_name AS uninomial,
           NULL AS genus,
           NULL AS infragenericEpithet,
           NULL AS specificEpithet,
           NULL AS infraspeciesEpithet,
           (SELECT documentation_id FROM reference_links rl WHERE rl.original_desc_ind='Y' AND rl.tsn=tu.TSN AND doc_id_prefix='PUB' LIMIT 1) AS publishedInID,
           CASE WHEN tu.kingdom_id=1 THEN 'bacterial' WHEN tu.kingdom_id=2 THEN 'zoological' WHEN tu.kingdom_id=3 THEN 'botanical' WHEN tu.kingdom_id=4 THEN 'botanical' WHEN tu.kingdom_id=5 THEN 'zoological' WHEN tu.kingdom_id=6 THEN 'botanical' WHEN tu.kingdom_id=7 THEN 'bacterial' END AS code,
           'http://purl.obolibrary.org/obo/NOMEN_XXXXXXXX' AS status,
           CONCAT('https://www.itis.gov/servlet/SingleRpt/SingleRpt?search_topic=TSN&search_value=', TSN) AS link,
           tu.kingdom_id,
           tu.name_usage,
           tu.unaccept_reason
    FROM taxonomic_units tu
        LEFT JOIN taxon_authors_lkp tal ON tu.taxon_author_id = tal.taxon_author_id
        LEFT JOIN taxon_unit_types tut ON tu.rank_id = tut.rank_id AND tu.kingdom_id = tut.kingdom_id
    WHERE tu.rank_id < 220
    UNION ALL
    SELECT TSN AS ID,
           complete_name AS scientificName,
           tal.taxon_author AS authorship,
           LOWER(tut.rank_name) AS `rank`,
           NULL       AS uninomial,
           unit_name1 AS genus,
           NULL       AS infragenericEpithet,
           unit_name2 AS specificEpithet,
           unit_name3 AS infraspeciesEpithet,
           (SELECT documentation_id FROM reference_links rl WHERE rl.original_desc_ind='Y' AND rl.tsn=tu.TSN AND doc_id_prefix='PUB' LIMIT 1) AS publishedInID,
           CASE WHEN tu.kingdom_id=1 THEN 'bacterial' WHEN tu.kingdom_id=2 THEN 'zoological' WHEN tu.kingdom_id=3 THEN 'botanical' WHEN tu.kingdom_id=4 THEN 'botanical' WHEN tu.kingdom_id=5 THEN 'zoological' WHEN tu.kingdom_id=6 THEN 'botanical' WHEN tu.kingdom_id=7 THEN 'bacterial' END AS code,
           NULL AS status,
           CONCAT('https://www.itis.gov/servlet/SingleRpt/SingleRpt?search_topic=TSN&search_value=', TSN) AS link,
           tu.kingdom_id,
           tu.name_usage,
           tu.unaccept_reason
    FROM taxonomic_units tu
        LEFT JOIN taxon_authors_lkp tal ON tu.taxon_author_id = tal.taxon_author_id
        LEFT JOIN taxon_unit_types tut ON tu.rank_id = tut.rank_id AND tu.kingdom_id = tut.kingdom_id
    WHERE tu.rank_id >= 220 AND unit_name2 NOT LIKE '(%)'
    UNION ALL
    SELECT TSN AS ID,
           complete_name AS scientificName,
           tal.taxon_author AS authorship,
           LOWER(tut.rank_name) AS `rank`,
           NULL       AS uninomial,
           unit_name1 AS genus,
           REGEXP_REPLACE(unit_name2, '[\(]{1}(.+)[\)]{1}', '$1') AS infragenericEpithet,
           unit_name3 AS specificEpithet,
           unit_name4 AS infraspeciesEpithet,
           (SELECT documentation_id FROM reference_links rl WHERE rl.original_desc_ind='Y' AND rl.tsn=tu.TSN AND doc_id_prefix='PUB' LIMIT 1) AS publishedInID,
           CASE WHEN tu.kingdom_id=1 THEN 'bacterial' WHEN tu.kingdom_id=2 THEN 'zoological' WHEN tu.kingdom_id=3 THEN 'botanical' WHEN tu.kingdom_id=4 THEN 'botanical' WHEN tu.kingdom_id=5 THEN 'zoological' WHEN tu.kingdom_id=6 THEN 'botanical' WHEN tu.kingdom_id=7 THEN 'bacterial' END AS code,
           NULL AS status,
           CONCAT('https://www.itis.gov/servlet/SingleRpt/SingleRpt?search_topic=TSN&search_value=', TSN) AS link,
           tu.kingdom_id,
           tu.name_usage,
           tu.unaccept_reason
    FROM taxonomic_units tu
        LEFT JOIN taxon_authors_lkp tal ON tu.taxon_author_id = tal.taxon_author_id
        LEFT JOIN taxon_unit_types tut ON tu.rank_id = tut.rank_id AND tu.kingdom_id = tut.kingdom_id
    WHERE tu.rank_id >= 220 AND unit_name2 LIKE '(%)'
);
CREATE INDEX name_id
	ON coldp.Name (ID);

# Set name status
UPDATE coldp.Name SET status=NULL;
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000224' WHERE kingdom_id='5' AND unaccept_reason IS NULL AND name_usage='valid';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000287' WHERE kingdom_id='5' AND unaccept_reason='homonym & junior synonym' AND name_usage='invalid';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000289' WHERE kingdom_id='5' AND unaccept_reason='junior homonym' AND name_usage='invalid';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000276' WHERE kingdom_id='5' AND unaccept_reason='junior synonym' AND name_usage='invalid';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000274' WHERE kingdom_id='5' AND unaccept_reason='misapplied' AND name_usage='invalid';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000225' WHERE kingdom_id='5' AND unaccept_reason='nomen dubium' AND name_usage='invalid';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000284' WHERE kingdom_id='5' AND unaccept_reason='nomen oblitum' AND name_usage='invalid';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000132' WHERE kingdom_id='5' AND unaccept_reason='original name/combination' AND name_usage='invalid';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000272' WHERE kingdom_id='5' AND unaccept_reason='other, see comments' AND name_usage='invalid';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000131' WHERE kingdom_id='5' AND unaccept_reason='subsequent name/combination' AND name_usage='invalid';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000028' WHERE kingdom_id='5' AND unaccept_reason='unavailable, database artifact' AND name_usage='invalid';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000044' WHERE kingdom_id='5' AND unaccept_reason='unavailable, incorrect orig. spelling' AND name_usage='invalid';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000275' WHERE kingdom_id='5' AND unaccept_reason='unavailable, literature misspelling' AND name_usage='invalid';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000174' WHERE kingdom_id='5' AND unaccept_reason='unavailable, nomen nudum' AND name_usage='invalid';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000168' WHERE kingdom_id='5' AND unaccept_reason='unavailable, other' AND name_usage='invalid';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000219' WHERE kingdom_id='5' AND unaccept_reason='unavailable, suppressed by ruling' AND name_usage='invalid';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000278' WHERE kingdom_id='5' AND unaccept_reason='unjustified emendation' AND name_usage='invalid';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000279' WHERE kingdom_id='5' AND unaccept_reason='unnecessary replacement' AND name_usage='invalid';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000272' WHERE kingdom_id='5' AND unaccept_reason='unspecified in provided data' AND name_usage='invalid';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000224' WHERE kingdom_id='2' AND unaccept_reason IS NULL AND name_usage='valid';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000276' WHERE kingdom_id='2' AND unaccept_reason='junior synonym' AND name_usage='invalid';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000132' WHERE kingdom_id='2' AND unaccept_reason='original name/combination' AND name_usage='invalid';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000272' WHERE kingdom_id='2' AND unaccept_reason='other, see comments' AND name_usage='invalid';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000131' WHERE kingdom_id='2' AND unaccept_reason='subsequent name/combination' AND name_usage='invalid';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000174' WHERE kingdom_id='2' AND unaccept_reason='unavailable, nomen nudum' AND name_usage='invalid';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000081' WHERE kingdom_id='7' AND unaccept_reason IS NULL AND name_usage='valid';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000096' WHERE kingdom_id='7' AND unaccept_reason='junior synonym' AND name_usage='invalid';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000132' WHERE kingdom_id='7' AND unaccept_reason='original name/combination' AND name_usage='invalid';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000135' WHERE kingdom_id='7' AND unaccept_reason='subsequent name/combination' AND name_usage='invalid';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000099' WHERE kingdom_id='7' AND unaccept_reason='unavailable, literature misspelling' AND name_usage='invalid';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000083' WHERE kingdom_id='7' AND unaccept_reason='unavailable, other' AND name_usage='invalid';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000104' WHERE kingdom_id='7' AND unaccept_reason='unavailable, suppressed by ruling' AND name_usage='invalid';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000081' WHERE kingdom_id='1' AND unaccept_reason IS NULL AND name_usage='valid';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000096' WHERE kingdom_id='1' AND unaccept_reason='junior synonym' AND name_usage='invalid';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000132' WHERE kingdom_id='1' AND unaccept_reason='original name/combination' AND name_usage='invalid';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000093' WHERE kingdom_id='1' AND unaccept_reason='other, see comments' AND name_usage='invalid';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000135' WHERE kingdom_id='1' AND unaccept_reason='subsequent name/combination' AND name_usage='invalid';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000083' WHERE kingdom_id='1' AND unaccept_reason='unavailable, other' AND name_usage='invalid';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000104' WHERE kingdom_id='1' AND unaccept_reason='unavailable, suppressed by ruling' AND name_usage='invalid';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000093' WHERE kingdom_id='1' AND unaccept_reason='unspecified in provided data' AND name_usage='invalid';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000383' WHERE kingdom_id='6' AND unaccept_reason IS NULL AND name_usage='accepted';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000016' WHERE kingdom_id='6' AND unaccept_reason='homonym (illegitimate)' AND name_usage='not accepted';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000379' WHERE kingdom_id='6' AND unaccept_reason='invalidly published, nomen nudum' AND name_usage='not accepted';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000008' WHERE kingdom_id='6' AND unaccept_reason='invalidly published, other' AND name_usage='not accepted';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000375' WHERE kingdom_id='6' AND unaccept_reason='orthographic variant (misspelling)' AND name_usage='not accepted';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000369' WHERE kingdom_id='6' AND unaccept_reason='other, see comments' AND name_usage='not accepted';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000385' WHERE kingdom_id='6' AND unaccept_reason='rejected name' AND name_usage='not accepted';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000372' WHERE kingdom_id='6' AND unaccept_reason='synonym' AND name_usage='not accepted';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000383' WHERE kingdom_id='4' AND unaccept_reason IS NULL AND name_usage='accepted';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000016' WHERE kingdom_id='4' AND unaccept_reason='homonym (illegitimate)' AND name_usage='not accepted';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000379' WHERE kingdom_id='4' AND unaccept_reason='invalidly published, nomen nudum' AND name_usage='not accepted';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000008' WHERE kingdom_id='4' AND unaccept_reason='invalidly published, other' AND name_usage='not accepted';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000375' WHERE kingdom_id='4' AND unaccept_reason='orthographic variant (misspelling)' AND name_usage='not accepted';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000369' WHERE kingdom_id='4' AND unaccept_reason='other, see comments' AND name_usage='not accepted';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000372' WHERE kingdom_id='4' AND unaccept_reason='synonym' AND name_usage='not accepted';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000383' WHERE kingdom_id='3' AND unaccept_reason IS NULL AND name_usage='accepted';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000016' WHERE kingdom_id='3' AND unaccept_reason='homonym (illegitimate)' AND name_usage='not accepted';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000130' WHERE kingdom_id='3' AND unaccept_reason='horticultural' AND name_usage='not accepted';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000379' WHERE kingdom_id='3' AND unaccept_reason='invalidly published, nomen nudum' AND name_usage='not accepted';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000008' WHERE kingdom_id='3' AND unaccept_reason='invalidly published, other' AND name_usage='not accepted';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000376' WHERE kingdom_id='3' AND unaccept_reason='misapplied' AND name_usage='not accepted';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000375' WHERE kingdom_id='3' AND unaccept_reason='orthographic variant (misspelling)' AND name_usage='not accepted';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000369' WHERE kingdom_id='3' AND unaccept_reason='other, see comments' AND name_usage='not accepted';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000385' WHERE kingdom_id='3' AND unaccept_reason='rejected name' AND name_usage='not accepted';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000015' WHERE kingdom_id='3' AND unaccept_reason='superfluous renaming (illegitimate)' AND name_usage='not accepted';
UPDATE coldp.Name SET status='http://purl.obolibrary.org/obo/NOMEN_0000372' WHERE kingdom_id='3' AND unaccept_reason='synonym' AND name_usage='not accepted';

# Drop extra ITIS columns used to set name status
ALTER TABLE coldp.Name DROP COLUMN kingdom_id;
ALTER TABLE coldp.Name DROP COLUMN name_usage;
ALTER TABLE coldp.Name DROP COLUMN unaccept_reason;



# TODO: Status
# Synonym
DROP TABLE IF EXISTS coldp.Synonym;
CREATE TABLE coldp.Synonym (
    SELECT CONCAT_WS('-', tsn_accepted, tsn) AS ID,
           tsn_accepted AS taxonID,
           tsn AS nameID,
           'synonym' AS status
FROM synonym_links sl
);
CREATE INDEX id
	ON coldp.Synonym (ID);
CREATE INDEX name_id
	ON coldp.Synonym (nameID);
CREATE INDEX taxon_id
	ON coldp.Synonym (taxonID);


# Distribution
DROP TABLE IF EXISTS coldp.Distribution;
CREATE TABLE coldp.Distribution (
    SELECT
        tsn AS taxonID,
        geographic_value AS area,
        'text' AS gazetteer,
        NULL AS status,
        NULL AS referenceID
    FROM geographic_div
);
CREATE INDEX taxon_id
	ON coldp.Distribution (taxonID);

# VernacularNames
DROP TABLE IF EXISTS coldp.VernacularName;
CREATE TABLE coldp.VernacularName (
    SELECT
        v.tsn AS taxonID,
        vernacular_name AS name,
        NULL AS transliteration,
        language,
        NULL AS country,
        NULL AS area,
        NULL AS sex,
        IF(vrl.doc_id_prefix='PUB', vrl.documentation_id, NULL) AS referenceID
    FROM vernaculars v
    LEFT JOIN vern_ref_links vrl ON v.vern_id = vrl.vern_id
);
CREATE INDEX taxon_id
	ON coldp.VernacularName (taxonID);


# References
DROP TABLE IF EXISTS coldp.Reference;
CREATE TABLE coldp.Reference (
    SELECT
        publication_id AS ID,
        NULL AS citation,
        reference_author AS author,
        title,
        YEAR(actual_pub_date) AS year,
        publication_name AS source,
        NULL As details,
        pub_comment AS remarks
    FROM publications
);
CREATE INDEX id
	ON coldp.Reference (id);
