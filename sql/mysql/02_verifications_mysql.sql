-- ============================================================
-- Projet DATAImmo
-- Fichier : 02_verifications_mysql.sql
-- Objectif : contrôles finaux du modèle et des données importées
-- SGBD : MySQL 8 / MySQL Workbench
-- ============================================================
--
-- À exécuter APRÈS :
--   1. 01_creation_bdd_DATAImmo.sql ;
--   2. scripts/01_prepare_clean_csv.py ;
--   3. scripts/02_import_clean_csv_mysql.py.
--
-- Ce fichier vérifie :
--   1. la structure générale du modèle final
--   2. les volumes importés dans les 7 tables
--   3. les valeurs nulles et les doublons sur les 7 PK
--   4. l'absence d'orphelins sur les 6 relations
--   5. la période des ventes et les types de locaux
--   6. l'absence de donnée identifiant un acquéreur
--   7. les contraintes effectivement déclarées dans MySQL
--
-- Tous les contrôles synthétiques doivent afficher "OK"
-- ============================================================

USE dataimmo;

-- ============================================================
-- 1. Vérification de la structure générale du modèle
--
-- Résultats attendus :
--   tables   = 7
--   colonnes = 33
--   PK       = 7
--   FK       = 6
-- ============================================================

SELECT
  structure_stats.tables_presentes,
  structure_stats.colonnes_presentes,
  CASE
    WHEN structure_stats.tables_presentes = 7
     AND structure_stats.colonnes_presentes = 33
    THEN 'OK'
    ELSE 'A CONTROLER'
  END AS statut
FROM (
  SELECT
    (
      SELECT COUNT(*)
      FROM information_schema.tables
      WHERE table_schema = DATABASE()
        AND table_type = 'BASE TABLE'
    ) AS tables_presentes,
    (
      SELECT COUNT(*)
      FROM information_schema.columns
      WHERE table_schema = DATABASE()
    ) AS colonnes_presentes
) AS structure_stats;

SELECT
  contraintes_stats.cles_primaires,
  contraintes_stats.cles_etrangeres,
  CASE
    WHEN contraintes_stats.cles_primaires = 7
     AND contraintes_stats.cles_etrangeres = 6
    THEN 'OK'
    ELSE 'A CONTROLER'
  END AS statut
FROM (
  SELECT
    SUM(constraint_type = 'PRIMARY KEY') AS cles_primaires,
    SUM(constraint_type = 'FOREIGN KEY') AS cles_etrangeres
  FROM information_schema.table_constraints
  WHERE constraint_schema = DATABASE()
) AS contraintes_stats;

-- ============================================================
-- 2. Vérification des volumes importés dans les 7 tables
--
-- Chaque volume MySQL doit être égal au volume attendu et le
-- statut de chaque ligne doit être "OK"
-- ============================================================

SELECT
  volumes.table_name,
  volumes.expected_rows,
  volumes.mysql_rows,
  CASE
    WHEN volumes.mysql_rows = volumes.expected_rows THEN 'OK'
    ELSE 'A CONTROLER'
  END AS statut
FROM (
  SELECT
    'region' AS table_name,
    19 AS expected_rows,
    COUNT(*) AS mysql_rows
  FROM region

  UNION ALL

  SELECT 'departement', 109, COUNT(*)
  FROM departement

  UNION ALL

  SELECT 'commune', 38916, COUNT(*)
  FROM commune

  UNION ALL

  SELECT 'population_commune', 34991, COUNT(*)
  FROM population_commune

  UNION ALL

  SELECT 'type_local', 2, COUNT(*)
  FROM type_local

  UNION ALL

  SELECT 'bien', 34169, COUNT(*)
  FROM bien

  UNION ALL

  SELECT 'vente', 34169, COUNT(*)
  FROM vente
) AS volumes;

-- ============================================================
-- 3. Vérification des 7 clés primaires
--
-- Résultats attendus pour chaque table :
--   valeurs_nulles    = 0
--   lignes_dupliquees = 0
--   statut            = OK
--
-- Une ligne dupliquée correspond à une occurrence supplémentaire
-- d'une clé déjà présente dans la même table
-- ============================================================

SELECT
  controles_pk.table_name,
  controles_pk.valeurs_nulles,
  controles_pk.lignes_dupliquees,
  CASE
    WHEN controles_pk.valeurs_nulles = 0
     AND controles_pk.lignes_dupliquees = 0
    THEN 'OK'
    ELSE 'A CONTROLER'
  END AS statut
FROM (
  SELECT
    'region' AS table_name,
    SUM(code_region IS NULL) AS valeurs_nulles,
    COUNT(*) - COUNT(DISTINCT code_region)
      - SUM(code_region IS NULL) AS lignes_dupliquees
  FROM region

  UNION ALL

  SELECT
    'departement',
    SUM(code_departement IS NULL),
    COUNT(*) - COUNT(DISTINCT code_departement)
      - SUM(code_departement IS NULL)
  FROM departement

  UNION ALL

  SELECT
    'commune',
    SUM(id_commune IS NULL),
    COUNT(*) - COUNT(DISTINCT id_commune)
      - SUM(id_commune IS NULL)
  FROM commune

  UNION ALL

  SELECT
    'population_commune',
    SUM(id_commune IS NULL),
    COUNT(*) - COUNT(DISTINCT id_commune)
      - SUM(id_commune IS NULL)
  FROM population_commune

  UNION ALL

  SELECT
    'type_local',
    SUM(code_type_local IS NULL),
    COUNT(*) - COUNT(DISTINCT code_type_local)
      - SUM(code_type_local IS NULL)
  FROM type_local

  UNION ALL

  SELECT
    'bien',
    SUM(id_bien IS NULL),
    COUNT(*) - COUNT(DISTINCT id_bien)
      - SUM(id_bien IS NULL)
  FROM bien

  UNION ALL

  SELECT
    'vente',
    SUM(id_vente IS NULL),
    COUNT(*) - COUNT(DISTINCT id_vente)
      - SUM(id_vente IS NULL)
  FROM vente
) AS controles_pk;

-- ============================================================
-- 4. Vérification de l'intégrité des 6 clés étrangères
--
-- Résultat attendu pour chaque relation :
--   lignes_orphelines = 0
--   statut            = OK
--
-- La FK bien.code_type_local accepte NULL. Seules les valeurs
-- renseignées sans correspondance sont donc considérées comme
-- orphelines
-- ============================================================

SELECT
  controles_fk.controle,
  controles_fk.lignes_orphelines,
  CASE
    WHEN controles_fk.lignes_orphelines = 0 THEN 'OK'
    ELSE 'A CONTROLER'
  END AS statut
FROM (
  SELECT
    'departement_sans_region' AS controle,
    COUNT(*) AS lignes_orphelines
  FROM departement d
  LEFT JOIN region r
    ON d.code_region = r.code_region
  WHERE r.code_region IS NULL

  UNION ALL

  SELECT 'commune_sans_departement', COUNT(*)
  FROM commune c
  LEFT JOIN departement d
    ON c.code_departement = d.code_departement
  WHERE d.code_departement IS NULL

  UNION ALL

  SELECT 'population_sans_commune', COUNT(*)
  FROM population_commune p
  LEFT JOIN commune c
    ON p.id_commune = c.id_commune
  WHERE c.id_commune IS NULL

  UNION ALL

  SELECT 'bien_sans_commune', COUNT(*)
  FROM bien b
  LEFT JOIN commune c
    ON b.id_commune = c.id_commune
  WHERE c.id_commune IS NULL

  UNION ALL

  SELECT 'bien_sans_type_local', COUNT(*)
  FROM bien b
  LEFT JOIN type_local t
    ON b.code_type_local = t.code_type_local
  WHERE b.code_type_local IS NOT NULL
    AND t.code_type_local IS NULL

  UNION ALL

  SELECT 'vente_sans_bien', COUNT(*)
  FROM vente v
  LEFT JOIN bien b
    ON v.id_bien = b.id_bien
  WHERE b.id_bien IS NULL
) AS controles_fk;

-- ============================================================
-- 5. Vérification du périmètre fonctionnel attendu
--
-- La période des ventes doit aller du 02/01/2020 au 30/06/2020
-- et contenir 34169 transactions
-- Les seuls types de locaux attendus sont Maison et Appartement
-- ============================================================

SELECT
  DATE_FORMAT(perimetre.premiere_date, '%d/%m/%Y') AS premiere_date,
  DATE_FORMAT(perimetre.derniere_date, '%d/%m/%Y') AS derniere_date,
  perimetre.nombre_ventes,
  CASE
    WHEN perimetre.premiere_date = '2020-01-02'
     AND perimetre.derniere_date = '2020-06-30'
     AND perimetre.nombre_ventes = 34169
    THEN 'OK'
    ELSE 'A CONTROLER'
  END AS statut
FROM (
  SELECT
    MIN(date_mutation) AS premiere_date,
    MAX(date_mutation) AS derniere_date,
    COUNT(*) AS nombre_ventes
  FROM vente
) AS perimetre;

SELECT
  COUNT(*) AS nombre_types,
  SUM(libelle_type_local = 'Maison') AS lignes_maison,
  SUM(libelle_type_local = 'Appartement') AS lignes_appartement,
  SUM(libelle_type_local NOT IN ('Maison', 'Appartement'))
    AS types_inattendus,
  CASE
    WHEN COUNT(*) = 2
     AND SUM(libelle_type_local = 'Maison') = 1
     AND SUM(libelle_type_local = 'Appartement') = 1
     AND SUM(libelle_type_local NOT IN ('Maison', 'Appartement')) = 0
    THEN 'OK'
    ELSE 'A CONTROLER'
  END AS statut
FROM type_local;

-- Répartition informative des biens par type de local
SELECT
  t.libelle_type_local,
  COUNT(*) AS nombre_biens
FROM bien b
INNER JOIN type_local t
  ON b.code_type_local = t.code_type_local
GROUP BY t.code_type_local, t.libelle_type_local
ORDER BY nombre_biens DESC;

-- ============================================================
-- 6. Contrôle de l'exclusion des données acquéreur
--
-- Résultat attendu :
--   colonnes_interdites = 0
--   statut              = OK
--
-- Le second résultat reste vide lorsque le contrôle est valide
-- ============================================================

SELECT
  COUNT(*) AS colonnes_interdites,
  CASE
    WHEN COUNT(*) = 0 THEN 'OK'
    ELSE 'A CONTROLER'
  END AS statut
FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND LOWER(column_name) REGEXP 'acquereur|acheteur|buyer';

SELECT
  table_name,
  column_name
FROM information_schema.columns
WHERE table_schema = DATABASE()
  AND LOWER(column_name) REGEXP 'acquereur|acheteur|buyer'
ORDER BY table_name, ordinal_position;

-- ============================================================
-- 7. Liste des contraintes déclarées dans MySQL
--
-- Cette dernière requête fournit le détail des 7 clés primaires
-- et des 6 clés étrangères contrôlées dans la première section
-- ============================================================

SELECT
  table_name,
  constraint_name,
  constraint_type
FROM information_schema.table_constraints
WHERE constraint_schema = DATABASE()
  AND constraint_type IN ('PRIMARY KEY', 'FOREIGN KEY')
ORDER BY
  table_name,
  FIELD(constraint_type, 'PRIMARY KEY', 'FOREIGN KEY'),
  constraint_name;

-- ============================================================
-- Fin des vérifications MySQL
-- Tous les statuts synthétiques doivent afficher "OK" avant
-- d'utiliser la base pour les analyses métier
-- ============================================================