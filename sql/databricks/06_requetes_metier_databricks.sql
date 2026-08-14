-- ============================================================
-- Projet       : DATAImmo
-- Fichier      : 06_requetes_metier_databricks.sql
-- Objectif     : Répondre aux douze demandes métier officielles
--                à partir du modèle relationnel final
-- Environnement: Databricks SQL / Unity Catalog
-- ============================================================
--
-- Prérequis :
-- 1. Avoir importé et vérifié les sept tables.
-- 2. Avoir déclaré les 7 PK et les 6 FK avec le fichier 05
--
-- Règles communes :
-- - les divisions par surface excluent les surfaces nulles ou
--   inférieures ou égales à zéro
-- - les moyennes excluent les valeurs foncières nulles
-- - les dates techniques utilisent le format ISO AAAA-MM-JJ
--
-- Résultat attendu :
-- Chaque section produit le résultat associé à une demande
-- métier, sans modifier les données des sept tables
-- ============================================================


-- ============================================================
-- 1. SÉLECTION DU CATALOGUE ET DU SCHÉMA
-- ============================================================

USE CATALOG workspace;
USE SCHEMA dataimmo;

-- ============================================================
-- 2. DEMANDES MÉTIER
-- ============================================================

-- ------------------------------------------------------------
-- QUESTION 1
-- Nombre total d'appartements vendus au premier semestre 2020
-- Résultat : une ligne contenant le nombre d'appartements vendus
-- ------------------------------------------------------------
SELECT COUNT(*) AS nombre_appartements_vendus
FROM vente v
JOIN bien b
    ON v.id_bien = b.id_bien
JOIN type_local t
    ON b.code_type_local = t.code_type_local
WHERE t.libelle_type_local = 'Appartement'
  AND v.date_mutation BETWEEN DATE '2020-01-01' AND DATE '2020-06-30';

-- ------------------------------------------------------------
-- QUESTION 2
-- Nombre de ventes d'appartements par région au premier semestre
-- 2020, classé du nombre de ventes le plus élevé au plus faible
-- ------------------------------------------------------------
SELECT
    r.nom_region,
    COUNT(*) AS nombre_ventes_appartements
FROM vente v
JOIN bien b
    ON v.id_bien = b.id_bien
JOIN type_local t
    ON b.code_type_local = t.code_type_local
JOIN commune c
    ON b.id_commune = c.id_commune
JOIN departement d
    ON c.code_departement = d.code_departement
JOIN region r
    ON d.code_region = r.code_region
WHERE t.libelle_type_local = 'Appartement'
  AND v.date_mutation BETWEEN DATE '2020-01-01' AND DATE '2020-06-30'
GROUP BY r.code_region, r.nom_region
ORDER BY nombre_ventes_appartements DESC;

-- ------------------------------------------------------------
-- QUESTION 3
-- Proportion des ventes d'appartements selon le nombre de pièces
-- Résultat : effectif et pourcentage pour chaque nombre de pièces
-- ------------------------------------------------------------
WITH ventes_par_pieces AS (
    SELECT
        b.nombre_pieces_principales AS nombre_pieces,
        COUNT(*) AS nombre_ventes
    FROM vente v
    JOIN bien b
        ON v.id_bien = b.id_bien
    JOIN type_local t
        ON b.code_type_local = t.code_type_local
    WHERE t.libelle_type_local = 'Appartement'
      AND v.date_mutation BETWEEN DATE '2020-01-01' AND DATE '2020-06-30'
    GROUP BY b.nombre_pieces_principales
)
SELECT
    nombre_pieces,
    nombre_ventes,
    ROUND(
        100.0 * nombre_ventes / SUM(nombre_ventes) OVER (),
        2
    ) AS proportion_pourcentage
FROM ventes_par_pieces
ORDER BY nombre_pieces;

-- ------------------------------------------------------------
-- QUESTION 4
-- Dix départements ayant le prix moyen au m² le plus élevé
-- Résultat : un classement décroissant limité à dix lignes
-- ------------------------------------------------------------
SELECT
    d.code_departement,
    d.nom_departement,
    ROUND(AVG(v.valeur_fonciere / b.surface_reelle_bati), 2) AS prix_moyen_m2
FROM vente v
JOIN bien b
    ON v.id_bien = b.id_bien
JOIN commune c
    ON b.id_commune = c.id_commune
JOIN departement d
    ON c.code_departement = d.code_departement
WHERE v.valeur_fonciere IS NOT NULL
  AND b.surface_reelle_bati > 0
GROUP BY d.code_departement, d.nom_departement
ORDER BY prix_moyen_m2 DESC
LIMIT 10;

-- ------------------------------------------------------------
-- QUESTION 5
-- Prix moyen au m² d'une maison située en Île-de-France
-- Le code région 11 correspond à l'Île-de-France
-- ------------------------------------------------------------
SELECT
    ROUND(
        AVG(v.valeur_fonciere / b.surface_reelle_bati),
        2
    ) AS prix_moyen_m2_maison_idf
FROM vente v
JOIN bien b
    ON v.id_bien = b.id_bien
JOIN type_local t
    ON b.code_type_local = t.code_type_local
JOIN commune c
    ON b.id_commune = c.id_commune
JOIN departement d
    ON c.code_departement = d.code_departement
JOIN region r
    ON d.code_region = r.code_region
WHERE t.libelle_type_local = 'Maison'
  AND r.code_region = '11'
  AND v.valeur_fonciere IS NOT NULL
  AND b.surface_reelle_bati > 0;

-- ------------------------------------------------------------
-- QUESTION 6
-- Dix appartements ayant la valeur foncière la plus élevée, avec
-- leur commune, leur région et leur surface réelle bâtie
-- ------------------------------------------------------------
SELECT
    v.id_vente,
    c.nom_commune,
    r.nom_region,
    b.surface_reelle_bati AS surface_m2,
    v.valeur_fonciere
FROM vente v
JOIN bien b
    ON v.id_bien = b.id_bien
JOIN type_local t
    ON b.code_type_local = t.code_type_local
JOIN commune c
    ON b.id_commune = c.id_commune
JOIN departement d
    ON c.code_departement = d.code_departement
JOIN region r
    ON d.code_region = r.code_region
WHERE t.libelle_type_local = 'Appartement'
  AND v.valeur_fonciere IS NOT NULL
ORDER BY v.valeur_fonciere DESC
LIMIT 10;

-- ------------------------------------------------------------
-- QUESTION 7
-- Taux d'évolution du nombre de ventes entre les premier et
-- deuxième trimestres 2020
-- ------------------------------------------------------------
WITH ventes_trimestrielles AS (
    SELECT
        SUM(
            CASE WHEN QUARTER(date_mutation) = 1 THEN 1 ELSE 0 END
        ) AS ventes_t1,
        SUM(
            CASE WHEN QUARTER(date_mutation) = 2 THEN 1 ELSE 0 END
        ) AS ventes_t2
    FROM vente
    WHERE date_mutation BETWEEN DATE '2020-01-01' AND DATE '2020-06-30'
)
SELECT
    ventes_t1,
    ventes_t2,
    ROUND(
        100.0 * (ventes_t2 - ventes_t1) / ventes_t1,
        2
    ) AS taux_evolution_pourcentage
FROM ventes_trimestrielles;

-- ------------------------------------------------------------
-- QUESTION 8
-- Classement des régions par prix moyen au m² des appartements
-- de plus de quatre pièces
-- ------------------------------------------------------------
SELECT
    r.nom_region,
    COUNT(*) AS nombre_ventes,
    ROUND(AVG(v.valeur_fonciere / b.surface_reelle_bati), 2) AS prix_moyen_m2
FROM vente v
JOIN bien b
    ON v.id_bien = b.id_bien
JOIN type_local t
    ON b.code_type_local = t.code_type_local
JOIN commune c
    ON b.id_commune = c.id_commune
JOIN departement d
    ON c.code_departement = d.code_departement
JOIN region r
    ON d.code_region = r.code_region
WHERE t.libelle_type_local = 'Appartement'
  AND b.nombre_pieces_principales > 4
  AND v.valeur_fonciere IS NOT NULL
  AND b.surface_reelle_bati > 0
GROUP BY r.code_region, r.nom_region
ORDER BY prix_moyen_m2 DESC;

-- ------------------------------------------------------------
-- QUESTION 9
-- Communes ayant enregistré au moins cinquante ventes au premier
-- trimestre 2020
-- ------------------------------------------------------------
SELECT
    c.id_commune,
    c.nom_commune,
    COUNT(*) AS nombre_ventes_t1
FROM vente v
JOIN bien b
    ON v.id_bien = b.id_bien
JOIN commune c
    ON b.id_commune = c.id_commune
WHERE v.date_mutation BETWEEN DATE '2020-01-01' AND DATE '2020-03-31'
GROUP BY c.id_commune, c.nom_commune
HAVING COUNT(*) >= 50
ORDER BY nombre_ventes_t1 DESC;

-- ------------------------------------------------------------
-- QUESTION 10
-- Différence de prix moyen au m² entre les appartements de deux
-- pièces et ceux de trois pièces
-- ------------------------------------------------------------
WITH prix_par_pieces AS (
    SELECT
        b.nombre_pieces_principales AS nombre_pieces,
        AVG(v.valeur_fonciere / b.surface_reelle_bati) AS prix_moyen_m2
    FROM vente v
    JOIN bien b
        ON v.id_bien = b.id_bien
    JOIN type_local t
        ON b.code_type_local = t.code_type_local
    WHERE t.libelle_type_local = 'Appartement'
      AND b.nombre_pieces_principales IN (2, 3)
      AND v.valeur_fonciere IS NOT NULL
      AND b.surface_reelle_bati > 0
    GROUP BY b.nombre_pieces_principales
),
comparaison AS (
    SELECT
        MAX(
            CASE WHEN nombre_pieces = 2 THEN prix_moyen_m2 END
        ) AS prix_m2_2_pieces,
        MAX(
            CASE WHEN nombre_pieces = 3 THEN prix_moyen_m2 END
        ) AS prix_m2_3_pieces
    FROM prix_par_pieces
)
SELECT
    ROUND(prix_m2_2_pieces, 2) AS prix_m2_2_pieces,
    ROUND(prix_m2_3_pieces, 2) AS prix_m2_3_pieces,
    ROUND(
        100.0 * (prix_m2_3_pieces - prix_m2_2_pieces)
        / prix_m2_2_pieces,
        2
    ) AS difference_pourcentage
FROM comparaison;

-- ------------------------------------------------------------
-- QUESTION 11
-- Trois communes ayant la valeur foncière moyenne la plus élevée
-- dans chacun des départements 06, 13, 33, 59 et 69
-- ------------------------------------------------------------
WITH moyenne_commune AS (
    SELECT
        d.code_departement,
        d.nom_departement,
        c.id_commune,
        c.nom_commune,
        AVG(v.valeur_fonciere) AS valeur_fonciere_moyenne
    FROM vente v
    JOIN bien b
        ON v.id_bien = b.id_bien
    JOIN commune c
        ON b.id_commune = c.id_commune
    JOIN departement d
        ON c.code_departement = d.code_departement
    WHERE d.code_departement IN ('06', '13', '33', '59', '69')
      AND v.valeur_fonciere IS NOT NULL
    GROUP BY
        d.code_departement,
        d.nom_departement,
        c.id_commune,
        c.nom_commune
),
classement AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY code_departement
            ORDER BY valeur_fonciere_moyenne DESC
        ) AS rang
    FROM moyenne_commune
)
SELECT
    code_departement,
    nom_departement,
    rang,
    nom_commune,
    ROUND(valeur_fonciere_moyenne, 2) AS valeur_fonciere_moyenne
FROM classement
WHERE rang <= 3
ORDER BY code_departement, rang;

-- ------------------------------------------------------------
-- QUESTION 12
-- Vingt communes de plus de 10 000 habitants ayant le plus de
-- transactions pour 1 000 habitants
-- ------------------------------------------------------------
WITH transactions_commune AS (
    SELECT
        c.id_commune,
        c.nom_commune,
        COUNT(*) AS nombre_transactions
    FROM vente v
    JOIN bien b
        ON v.id_bien = b.id_bien
    JOIN commune c
        ON b.id_commune = c.id_commune
    GROUP BY c.id_commune, c.nom_commune
)
SELECT
    t.id_commune,
    t.nom_commune,
    p.population_totale,
    t.nombre_transactions,
    ROUND(
        1000.0 * t.nombre_transactions / p.population_totale,
        2
    ) AS transactions_pour_1000_habitants
FROM transactions_commune t
JOIN population_commune p
    ON t.id_commune = p.id_commune
WHERE p.population_totale > 10000
ORDER BY transactions_pour_1000_habitants DESC
LIMIT 20;