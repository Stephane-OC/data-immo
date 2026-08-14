-- ============================================================
-- Projet       : DATAImmo
-- Fichier      : 01_creation_schema_databricks.sql
-- Objectif     : Réinitialiser le schéma Unity Catalog utilisé
--                pour importer les sept tables du modèle final
-- Environnement: Databricks SQL / Unity Catalog
-- ============================================================
--
-- ATTENTION : la commande DROP SCHEMA ... CASCADE supprime le
-- schéma dataimmo ainsi que toutes les tables qu'il contient
-- Exécuter ce script uniquement si les résultats utiles ont été
-- sauvegardés et si la base doit réellement être reconstruite
--
-- Prérequis :
-- 1. Disposer du catalogue Unity Catalog "workspace"
-- 2. Avoir généré les sept CSV nettoyés dans "data/clean"
-- 3. Disposer des droits de création de schéma et de tables
--
-- Ordre d'exécution du workflow Databricks :
-- 1. Exécuter 01_creation_schema_databricks.sql
-- 2. Importer manuellement les sept CSV avec Add data
-- 3. Exécuter 02_verifications_nombres_databricks.sql
-- 4. Exécuter 03_verifications_doublons_databricks.sql
-- 5. Exécuter 04_verifications_integrite_databricks.sql
-- 6. Exécuter 05_declaration_contraintes_databricks.sql
-- 7. Exécuter 06_requetes_metier_databricks.sql
--
-- Résultat attendu :
-- Le schéma "workspace.dataimmo" est vide et prêt à recevoir les
-- sept tables du modèle relationnel final
-- ============================================================


-- ============================================================
-- 1. SÉLECTION DU CATALOGUE UNITY CATALOG
-- ============================================================

-- Le catalogue "workspace" permet de déclarer ensuite les clés
-- primaires et étrangères informatives de Databricks
USE CATALOG workspace;

-- ============================================================
-- 2. RÉINITIALISATION DU SCHÉMA DATAIMMO
-- ============================================================

-- Supprime l'ancienne version du schéma et toutes ses tables
DROP SCHEMA IF EXISTS dataimmo CASCADE;

-- Crée un schéma propre, puis le sélectionne pour la suite
CREATE SCHEMA IF NOT EXISTS dataimmo;
USE SCHEMA dataimmo;

-- ============================================================
-- 3. IMPORT MANUEL DES SEPT CSV NETTOYÉS
-- ============================================================

-- Dans Databricks, utiliser Add data pour importer les fichiers
-- de "data/clean" dans l'ordre suivant :
--
-- 1. region.csv
-- 2. departement.csv
-- 3. commune.csv
-- 4. population_commune.csv
-- 5. type_local.csv
-- 6. bien.csv
-- 7. vente.csv
--
-- Paramètres communs à appliquer pendant chaque import :
-- - première ligne utilisée comme en-tête
-- - séparateur de colonnes : point-virgule (";")
-- - création des tables dans "workspace.dataimmo"
-- - format de table : Delta

-- ============================================================
-- 4. TYPES À IMPOSER LORS DE L'IMPORT
-- ============================================================

-- region
--   code_region                       STRING
--   nom_region                        STRING
--
-- departement
--   code_departement                  STRING
--   nom_departement                   STRING
--   code_region                       STRING
--
-- commune
--   id_commune                        STRING
--   code_departement                  STRING
--   code_commune                      STRING
--   nom_commune                       STRING
--
-- population_commune
--   id_commune                        STRING
--   population_municipale             BIGINT
--   population_comptee_a_part         BIGINT
--   population_totale                 BIGINT
--
-- type_local
--   code_type_local                   BIGINT
--   libelle_type_local                STRING
--
-- bien
--   id_bien                           BIGINT
--   id_commune                        STRING
--   numero_voie                       BIGINT
--   btq                               STRING
--   type_voie                         STRING
--   voie                              STRING
--   code_postal                       STRING
--   surface_carrez                    DECIMAL(10,2)
--   surface_reelle_bati               DECIMAL(10,2)
--   nombre_pieces_principales         BIGINT
--   code_type_local                   BIGINT
--
-- vente
--   id_vente                          BIGINT
--   id_bien                           BIGINT
--   numero_disposition                BIGINT
--   date_mutation                     DATE
--   nature_mutation                   STRING
--   valeur_fonciere                   DECIMAL(14,2)
--   nombre_lots                       BIGINT

-- ============================================================
-- 5. POINTS DE VIGILANCE
-- ============================================================

-- Les codes géographiques et postaux doivent rester en STRING
-- afin de préserver leurs zéros initiaux : 01, 06 ou 01000
--
-- Les noms et prénoms des acquéreurs ne doivent jamais être
-- importés dans les tables nettoyées du modèle final
--
-- Les clés sont déclarées seulement dans le fichier 05, après
-- validation des volumes, des doublons et de l'intégrité