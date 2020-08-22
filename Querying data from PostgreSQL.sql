------------------------------------------------------------------------------
--                          0. Importing Data                               --
------------------------------------------------------------------------------

-- Client
DROP TABLE IF EXISTS client;
CREATE TABLE client (
	IDCLIENT_BRUT real primary key, 
	CIVILITE varchar(10),
	DATENAISSANCE timestamp,
	MAGASIN varchar(15),
	DATEDEBUTADHESION timestamp,
	DATEREADHESION timestamp,
	DATEFINADHESION timestamp,
	VIP integer,
	CODEINSEE varchar(10),
	PAYS varchar(10)
);
COPY client FROM 'C:\DATA_Projet_R\CLIENT.CSV' CSV HEADER delimiter '|' null '';

---TRANSFORMATION IDCLIENT_BRUT
ALTER TABLE client ADD IDCLIENT_NEW bigint;
UPDATE client SET IDCLIENT_NEW =  CAST(IDCLIENT_BRUT AS bigint);
ALTER TABLE client DROP IDCLIENT_BRUT;
ALTER TABLE client ADD PRIMARY KEY (IDCLIENT_NEW);

-- Entete_Ticket
DROP TABLE IF EXISTS entete_ticket;
CREATE TABLE entete_ticket
(
	IDTICKET bigint primary key,
	TIC_DATE timestamp,
	MAG_CODE varchar(15),
	IDCLIENT_BRUT real,
	TIC_TOTALTTC_BRUT varchar(10) --money
);

COPY entete_ticket FROM 'C:\DATA_Projet_R\ENTETES_TICKET_V4.CSV' CSV HEADER delimiter '|' null '';

---TRANSFORMATION TIC_TOTALTTC_BRUT
ALTER TABLE entete_ticket ADD TIC_TOTALTTC float;
UPDATE entete_ticket SET TIC_TOTALTTC =  CAST(REPLACE(TIC_TOTALTTC_BRUT , ',', '.') AS float);
ALTER TABLE entete_ticket DROP TIC_TOTALTTC_BRUT;

---TRANSFORMATION IDCLIENT_BRUT
ALTER TABLE entete_ticket ADD IDCLIENT bigint;
UPDATE entete_ticket SET IDCLIENT =  CAST(IDCLIENT_BRUT AS bigint);
ALTER TABLE entete_ticket DROP IDCLIENT_BRUT;

-- Ligne_ticket
DROP TABLE IF EXISTS lignes_ticket;
CREATE TABLE lignes_ticket 
(
	IDTICKET bigint,
	NUMLIGNETICKET integer,
	IDARTICLE varchar(15),
	QUANTITE_BRUT varchar(15),
	MONTANTREMISE_BRUT varchar(15),
	TOTAL_BRUT varchar(15),
	MARGESORTIE_BRUT varchar(15)
);
COPY lignes_ticket FROM 'C:\DATA_Projet_R\LIGNES_TICKET_V4.CSV' CSV HEADER delimiter '|' null '';

---TRANSFORMATION QUANTITE_BRUT
ALTER TABLE lignes_ticket ADD QUANTITE float;
UPDATE lignes_ticket SET QUANTITE =  CAST(REPLACE(QUANTITE_BRUT , ',', '.') AS float);
ALTER TABLE lignes_ticket DROP QUANTITE_BRUT;

---TRANSFORMATION MONTANTREMISE_BRUT
ALTER TABLE lignes_ticket ADD MONTANTREMISE float;
UPDATE lignes_ticket SET MONTANTREMISE =  CAST(REPLACE(MONTANTREMISE_BRUT , ',', '.') AS float);
ALTER TABLE lignes_ticket DROP MONTANTREMISE_BRUT;

---TRANSFORMATION TOTAL_BRUT
ALTER TABLE lignes_ticket ADD TOTAL float;
UPDATE lignes_ticket SET TOTAL =  CAST(REPLACE(TOTAL_BRUT , ',', '.') AS float);
ALTER TABLE lignes_ticket DROP TOTAL_BRUT;

---TRANSFORMATION MARGESORTIE_BRUT
ALTER TABLE lignes_ticket ADD MARGESORTIE float;
UPDATE lignes_ticket SET MARGESORTIE =  CAST(REPLACE(MARGESORTIE_BRUT , ',', '.') AS float);
ALTER TABLE lignes_ticket DROP MARGESORTIE_BRUT;

-- REF_MAGASIN
DROP TABLE IF EXISTS ref_magasin;
CREATE TABLE ref_magasin 
(
	CODESOCIETE varchar(15) primary key,
	VILLE varchar(50),
	LIBELLEDEPARTEMENT integer,
	LIBELLEREGIONCOMMERCIALE varchar(15)
);
COPY ref_magasin FROM 'C:\DATA_Projet_R\REF_MAGASIN.CSV' CSV HEADER delimiter '|' null '';

-- REF_ARTICLE
DROP TABLE IF EXISTS ref_article;
CREATE TABLE ref_article 
(
	CODEARTICLE varchar(15) primary key,
	CODEUNIVERS varchar(15),
	CODEFAMILLE varchar(15),
	CODESOUSFAMILLE varchar(15)
);
COPY ref_article FROM 'C:\DATA_Projet_R\REF_ARTICLE.CSV' CSV HEADER delimiter '|' null '';

------------------------------------------------------------------------------
--                          1. Analysis of client and revenue               --
------------------------------------------------------------------------------

-- a. Répartition client
select factor, vip, new_n2, new_n1, adherent, churner
from 
(
-- Clients étant VIP: vip
	select count(idclient_new) as vip, count(idclient_new)/count(idclient_new) as factor
	from client where vip = 1
) as temp0
join 
(
-- Clients ayant adhéré au cours de l'année N-2: new_n2
	select count(idclient_new) as new_n2, count(idclient_new)/count(idclient_new) as factor
	from client where datedebutadhesion between '2016-01-01' and '2016-12-31'
	and vip = 0
) as temp1
using(factor)
join
(
-- Clients ayant adhéré au cours de l'année N-1: new_n1
	select count(idclient_new) as new_n1, count(idclient_new)/count(idclient_new) as factor
	from client where datedebutadhesion between '2017-01-01' and '2017-12-31'
	and vip = 0
) as temp2
using(factor)
join 
(
-- Clients toujours en cours d'adhésion: adherent
	select count(idclient_new) as adherent, count(idclient_new)/count(idclient_new) as factor
	from client where datefinadhesion>='2018-01-01' and datedebutadhesion<'2016-01-01'
	and vip = 0
) as temp3
using(factor)
join
(
-- Clients ayant churner: churner
	select count(idclient_new) as churner, count(idclient_new)/count(idclient_new) as factor
	from client where datefinadhesion <'2018-01-01' and datedebutadhesion <'2016-01-01'
	and vip=0) as temp4
using(factor);

-- b. Comportement du CA GLOBAL par client N-2 vs N-1
select *
from(
select idclient_new, case when annee = 2016 then sum_ca else NULL end as ca_2016
from
(
-- CA global par client N-2
	select idclient_new, extract(year from tic_date) as annee, sum(tic_totalttc) as sum_ca
	from entete_ticket inner join client on entete_ticket.idclient = client.idclient_new
	where extract(year from tic_date) = 2016
	group by idclient_new, extract(year from tic_date)
) as temp0
group by 1, 2) as temp1
join
(	select idclient_new, case when annee = 2017 then sum_ca else NULL end as ca_2017
	from
(
-- CA global par client N-1
	select idclient_new, extract(year from tic_date) as annee, sum(tic_totalttc) as sum_ca
	from entete_ticket inner join client on entete_ticket.idclient = client.idclient_new
	where extract(year from tic_date) = 2017
	group by idclient_new, extract(year from tic_date)
) as temp1
group by 1, 2) as temp2
using(idclient_new);

-- Ajout de la colonne qui concatène age et gender

alter table client add age_sex character(20);
update client set age_sex = concat(gender, age);

-- On ne tiens pas compte des valeurs inférieures à 18 et supérieures à 100 (s'agissant de client adhérents)
copy(
select gender, age, round(num/(select sum(num) from (select gender, age, count(age_sex) as num
											   from client 
											   where age is not null and (age >= 18 and age <= 100)
											   group by gender, age) as temp2)*100, 2) as pct
from (select gender, age, count(age_sex) as num
	  from client 
	  where age is not null and (age >= 18 and age <= 100)
	  group by gender, age) as temp1
group by gender, age, num) to 'C:\DATA_Projet_R\1c.CSV' csv header delimiter '|' null ''; 

------------------------------------------------------------------------------
--                          2. Analysis of selling points                   --
------------------------------------------------------------------------------

-- a. Résultat par magasin
select * from
(
-- Indice évolution: indice_evol
	select *,
		case 
		when pct_nb_actif > 0 and dif_ttc > 0 then 'positive'
		when pct_nb_actif < 0 and dif_ttc < 0 then 'negative'
		else 'moyen' end as indice_evol
	from
 (
	 select codesociete, Nb_client, Nb_client_actif_2016, Nb_client_actif_2017, pct_nb_actif,
	 round(total_ttc_2016) as total_ttc_2016, round(total_ttc_2017) as total_ttc_2017, round(dif_ttc) as dif_ttc
	 from
  (
	  select codesociete, 
		Nb_client, 
		Nb_client_actif_2016, 
		Nb_client_actif_2017, 
		pct_nb_actif
	  from 
   (
-- Nombre des clients rattachés au magasin: Nb_client
	   select ref_magasin.codesociete, count(distinct idclient_new) as Nb_client
		 from ref_magasin inner join client on ref_magasin.codesociete = client.magasin
		 and ref_magasin.codesociete is not null
		 group by ref_magasin.codesociete
   ) as temp3
   join
   (
-- % Client N-2 vs N-1: pct_nb_actif
	   select codesociete, Nb_client_actif_2016, Nb_client_actif_2017,
	   round((Nb_client_actif_2017 - Nb_client_actif_2016) * 1.0 / Nb_client_actif_2016, 3) as pct_nb_actif
	from 
	(
-- Nombre de client actif sur N-2: Nb_client_actif_2016
		select mag_code as codesociete, count(distinct idclient) as Nb_client_actif_2016 from entete_ticket
		where extract(year from tic_date) = 2016
		group by mag_code
	) as temp8
	join
	(
-- Nombre de client actif sur N-1: Nb_client_actif_2017
		select mag_code as codesociete, count(distinct idclient) as Nb_client_actif_2017 from entete_ticket
		where extract(year from tic_date) = 2017
		group by mag_code
	) as temp2
	using (codesociete)) as temp4
   using (codesociete)) as temp5
  join 
  (
-- Différence entre N-2 et N-1: dif_ttc
	  select codesociete, total_ttc_2016, total_ttc_2017, (total_ttc_2017 - total_ttc_2016) as dif_ttc
	  from
   (
-- Total_ttc en N-2
	   select ref_magasin.codesociete, sum(tic_totalttc) as total_ttc_2016
	   from ref_magasin inner join entete_ticket on ref_magasin.codesociete = entete_ticket.mag_code
	   where extract (year from entete_ticket.tic_date) = 2016 and ref_magasin.codesociete is not null
	   group by ref_magasin.codesociete
   ) temp1
   join
   (
-- Total_ttc en N-1
	   select ref_magasin.codesociete, sum(tic_totalttc) as total_ttc_2017
	   from ref_magasin inner join entete_ticket on ref_magasin.codesociete = entete_ticket.mag_code
	   where extract (year from entete_ticket.tic_date) = 2017 and ref_magasin.codesociete is not null
	   group by ref_magasin.codesociete
   ) as temp2
   using (codesociete)) as temp0
  using (codesociete)) as temp6) as temp7
order by case 	when indice_evol = 'positive' then 1
				when indice_evol = 'moyen' then 2
				when indice_evol = 'negative' then 3 end;

-- b. Distance
-- Chargement des données: insee
drop table if exists insee;
create table insee (
	codeinsee varchar(10) primary key, 
	codepostal varchar(200),
	commune varchar(50),
	departement varchar(50),
	region varchar(50),
	statut varchar(50),
	alitude_moyenne decimal,
	superficie decimal,
	population decimal,
	geo_point_2d varchar(200),
	geo_shape varchar(2000000),
	id_geofla varchar(10),
	code_commune varchar(10),
	code_canton varchar(10),
	code_arrondissement varchar(10),
	code_departement varchar(10),
	code_region varchar(10)
);
copy insee from 'C:\DATA_Projet_R\INSEE.CSV' csv header delimiter ';' null '';

-- La fonction créée permet de calculer la distance par rapport à la longtitude et à la latitude
create or replace function calculate_distance(lat_client float, 
											  long_client float, 
											  lat_mag float, 
											  long_mag float)
returns float as $distance$ declare distance float = 0; 
begin
	distance = sin(pi() * lat_client / 180) 
				* sin(pi() * lat_mag / 180) 
				+ cos(pi() * lat_client / 180) 
				* cos(pi() * lat_mag / 180) 
				* cos(pi() * (long_client - long_mag) / 180);
	if distance > 1 then distance = 1; end if;
	distance = (acos(distance) * 180 / pi()) * 60 * 1.1515 * 1.609344;
-- 1 mile = 1.609344 kilometers
-- https://stackoverflow.com/questions/389211/geospatial-coordinates-and-distance-in-kilometers
	return distance;
end;
$distance$ language plpgsql;

-- Création d'une table qui combine client, magasin et leurs longitutes and latitudes
-- Extraction de la longtitude et  de la latitude du client du magasin et calcul de la distance qui les sépqre en utilisant la fonction créée: calculate_distance
select *,
		case 
		when dist_km <= 5 then '[0;5]'
		when dist_km > 5 and dist_km <= 10 then '(5;10]'
		when dist_km > 10 and dist_km <= 20 then '(10;20]'
		when dist_km > 20 and dist_km <= 50 then '(20;50]'
		else '>50' end as dist_km_interval
from
(select idclient_new, lat_client, long_client, 
		magasin, lat_mag , long_mag,
		calculate_distance(cast(lat_client as float), cast(long_client as float), cast(lat_mag as float), cast(long_mag as float)) as dist_km
from
(select client.idclient_new, client.magasin, mydata_temp1.long_client, mydata_temp1.lat_client from client 
 join
 -- Long lat client
(select idclient_new, 
    case when position(',' in geo_point_2d) > 0 
         then substring(geo_point_2d, 1, position(',' in geo_point_2d) -1) 
         else geo_point_2d end as long_client,
    case when position(',' in geo_point_2d) > 0 
         then substring(geo_point_2d, position(',' in geo_point_2d) +1, length(geo_point_2d))  
         else null end as lat_client
from insee inner join client on insee.codeinsee = client.codeinsee) as mydata_temp1
using (idclient_new)) as mydata_temp3
join
(select codesociete as magasin, long_mag, lat_mag
from ref_magasin
join
-- Long lat magasin
(select ville, 
    case when position(',' in geo_point_2d) > 0 
         then substring(geo_point_2d, 1, position(',' in geo_point_2d) - 1) 
         else geo_point_2d end long_mag, 
    case when position(',' in geo_point_2d) > 0 
         then substring(geo_point_2d, position(',' in geo_point_2d) + 1, length(geo_point_2d))  
         else null end as lat_mag
from insee inner join ref_magasin on insee.commune = ref_magasin.ville) as temp2
using(ville)) as temp4
using(magasin)) as temp5
group by 8, 1, 2, 3, 4, 5, 6, 7;

------------------------------------------------------------------------------
--                          3. Analysis of type of product                  --
------------------------------------------------------------------------------

-- a. N-2 / N-1 évolution du CA par univers
select codeunivers, ca_2016, ca_2017, (ca_2017 - ca_2016) as diff_ca
from
(select codeunivers, sum(total) as ca_2016
 from lignes_ticket inner join entete_ticket on lignes_ticket.idticket = entete_ticket.idticket
 inner join ref_article on lignes_ticket.idarticle = ref_article.codearticle
 where extract(year from tic_date) = 2016
 group by codeunivers) as temp1
join
(select codeunivers, sum(total) as ca_2017
 from lignes_ticket inner join entete_ticket on lignes_ticket.idticket = entete_ticket.idticket
 inner join ref_article on lignes_ticket.idarticle = ref_article.codearticle
 where extract(year from tic_date) = 2017
 group by codeunivers) as temp2
using(codeunivers);

-- b. Top 5 des familles les plus rentable par univers 
select *
from
(select codeunivers, codesousfamille, rentab, 
       row_number() over (partition by codeunivers order by rentab desc) as temp_rank 
 from 
 (select codeunivers, codesousfamille, sum(margesortie) as rentab
  from ref_article inner join lignes_ticket on ref_article.codearticle = lignes_ticket.idarticle
  group by codesousfamille, codeunivers) as temp1) as temp2
  where temp_rank <= 5;
