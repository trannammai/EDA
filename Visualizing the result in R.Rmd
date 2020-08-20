---
title: "Exploratory data analysis using SQL and R"
output:
  html_notebook: 
    toc: true
    toc_float: true
---
The objective of this report is to visualize the data exported from the SQL queries. This report consists of 3 main parts:
 
     I. Global study
     1. Customer breakdown
     2. Behavior of turnover per customer in N-2 (2016) and N-1 (2017)

     II. Study by store
     1. Evolution in terms of the number of active customers and turnover per store
     2. Distance between customer's home and store

     III. Study by type of product
     1. Evolution of turnover by type of product in N-2 (2016) and N-1 (2017)
     2. Top 5 of the most profitable families by universe

In each part, we provide the SQL query as well as the data exported from these queries and the visualizations that are developed in R.

Warning: Only run this Rmarkdow part by part, as parts containing SQL queries will return errors. If we run a part a second time, there will be an error (restart the data import beforehand)

```{r setup, include=FALSE}
rm(list=ls())
library(ggplot2)
library(ggthemes)
library(extrafont)
library(plyr)
library(scales)
library(formattable)
library(janitor)
library(readr)
```
```{r message=FALSE, warning=FALSE, include=FALSE}
X1a <- read_delim("Devoir a envoyer/Data/New dataset/1a.CSV", 
    "|", escape_double = FALSE, trim_ws = TRUE)
X1b <- read_delim("Devoir a envoyer/Data/New dataset/1b.CSV", 
    "|", escape_double = FALSE, trim_ws = TRUE)
X1c <- read_delim("Devoir a envoyer/Data/New dataset/1c.CSV", 
    "|", escape_double = FALSE, trim_ws = TRUE)
X2a <- read_delim("Devoir a envoyer/Data/New dataset/2a.CSV", 
    "|", escape_double = FALSE, trim_ws = TRUE)
X2b <- read_delim("Devoir a envoyer/Data/New dataset/2b.CSV", 
    "|", escape_double = FALSE, trim_ws = TRUE)
X3a <- read_delim("Devoir a envoyer/Data/New dataset/3a.CSV", 
    "|", escape_double = FALSE, trim_ws = TRUE)
X3b <- read_delim("Devoir a envoyer/Data/New dataset/3b.CSV", 
    "|", escape_double = FALSE, trim_ws = TRUE)
```
# I. Global study
## 1. Membership / VIP breakdown
### SQL query
```{sql}
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
-- Clients ayant churné: churner
	select count(idclient_new) as churner, count(idclient_new)/count(idclient_new) as factor
	from client where datefinadhesion <'2018-01-01' and datedebutadhesion <'2016-01-01'
	and vip=0) as temp4
using(factor);
```
### Result of the SQL query
- Breakdown of customers by type

```{r echo=FALSE}
head(X1a)
```
### Visualisation
```{r warning=FALSE}
# Transform data
X1a <- t(X1a)
X1a <- as.data.frame(X1a)
X1a$factor <- rownames(X1a)
colnames(X1a) <- c("count","factor")
X1a$count <- as.numeric(X1a$count)
X1a <- as.data.frame(X1a[-1,])

# Compute percentages
X1a$pct <- X1a$count / sum(X1a$count)

# Compute the cumulative percentages (top of each rectangle)
X1a$ymax <- cumsum(X1a$pct)

# Compute the bottom of each rectangle
X1a$ymin <- c(0, head(X1a$ymax, n=-1))

# Label position
X1a$labelPosition <- (X1a$ymax + X1a$ymin) / 2

# Label
X1a$label <- paste0(percent(X1a$pct))

# Plot
ggplot(X1a, aes(ymax=ymax, ymin=ymin, xmax=4, xmin=3, fill=as.factor(factor))) +
  geom_rect() +
  geom_label(x=3.5, aes(y=labelPosition, label=label), size=3) +
  scale_fill_brewer(palette=4) +
  coord_polar(theta="y") +
  xlim(c(2, 4)) +
  theme_void() +
  theme(legend.position = "right") +
  ggtitle("Répartition client") +
  theme(plot.title = element_text(hjust = 0.5)) + 
  guides(fill = guide_legend("Type de client"))
```
> The proportion of churner is the highest (34.79%) followed by the number of members (22.53%), new members 2016 (15.45%), and new members 2017 (14.18%) . The proportion of VIPs is only 13.6%.

## 2. Performance of turnover per customer N-2 vs N-1
### SQL query
```{sql}
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
```
### Result of SQL query data
```{r}
head(X1b)
```
### Visualisation
```{r message=FALSE, warning=FALSE}
X1bnew1 <- X1b[,c(1,3)]
X1bnew1$date_part <- '2016'
colnames(X1bnew1) <- c('idclient_new','tic_totalttc','date_part')
X1bnew2 <- X1b[,c(1,2)]
X1bnew2$date_part <- '2017'
colnames(X1bnew2) <- c('idclient_new','tic_totalttc','date_part')
X1bnew <- rbind(X1bnew1, X1bnew2)

X1bnew$date_part <- factor(X1bnew$date_part, levels = c("2016", "2017"))
ggplot(X1bnew, aes(x = date_part, y = tic_totalttc, color = date_part)) + 
  geom_boxplot() + 
  ggtitle("Comportement du CA global par client 2016 vs 2017") +
  theme(plot.title = element_text(hjust = 0.5)) + 
  theme(legend.title = element_blank()) +
  labs(x = "Année", y = "Chiffre d'affaires") +
  theme(axis.line = element_line(size=1, colour = "black"),
        panel.grid.major = element_line(colour = "#d3d3d3"), panel.grid.minor = element_blank(),
        panel.border = element_blank(), panel.background = element_blank()) +
  theme(plot.title = element_text(size = 14, family = "Tahoma", face = "bold"),
        text=element_text(family = "Tahoma"),
        axis.text.x = element_text(colour = "black", size = 10),
        axis.text.y = element_text(colour = "black", size = 10))

# Fonction pour retirer les outliers
remove_outliers <- function(x, na.rm = TRUE, ...) {
  qnt <- quantile(x, probs=c(.25, .75), na.rm = na.rm, ...)
  H <- 1.5 * IQR(x, na.rm = na.rm)
  y <- x
  y[x < (qnt[1] - H)] <- NA
  y[x > (qnt[2] + H)] <- NA
  y
}

X1bnew1bis <- as.data.frame(remove_outliers(X1bnew1$tic_totalttc))
X1bnew1bis$date_part <- '2016'
colnames(X1bnew1bis) <- c('tic_totalttc','date_part')
X1bnew2bis <- as.data.frame(remove_outliers(X1bnew2$tic_totalttc))
X1bnew2bis$date_part <- '2017'
colnames(X1bnew2bis) <- c('tic_totalttc','date_part')
X1bnewbis <- rbind(X1bnew1bis, X1bnew2bis)

ggplot(X1bnewbis, aes(x = date_part, y = remove_outliers(tic_totalttc), color = date_part)) + 
  geom_boxplot() + 
  ggtitle("Comportement du CA global par client 2016 vs 2017 (sans outliers)") +
  theme(plot.title = element_text(hjust = 0.5)) + 
  theme(legend.title = element_blank()) +
  labs(x = "Année", y = "Chiffre d'affaires") +
  theme(axis.line = element_line(size=1, colour = "black"),
        panel.grid.major = element_line(colour = "#d3d3d3"), panel.grid.minor = element_blank(),
        panel.border = element_blank(), panel.background = element_blank()) +
  theme(plot.title = element_text(size = 14, family = "Tahoma", face = "bold"),
        text=element_text(family = "Tahoma"),
        axis.text.x = element_text(colour = "black", size = 10),
        axis.text.y = element_text(colour = "black", size = 10))
```
-CA 2016
```{r}
summary(X1bnew1bis$tic_totalttc)
```
-CA 2017
```{r}
summary(X1bnew2bis$tic_totalttc)
```

> In the first graph, customer behavior in terms of turnover is difficult to visualize because of the extreme values (outliers).
The second graph makes it possible to better highlight the median turnover which goes from 199 euros to 246 euros (the turnover below which is 50% of customer purchases). The average of purchases after excluding outliers goes from 265 euros to 316 euros.

## 3. Breakdown by age and sex
> We decided to limit the population to be represented in order to have a better distribution and better visibility of the age variable. As the clients studied are members, we have excluded those under 18 and over 100.

### Requête SQL
```{sql}
-- Constituer un graphique montrant la répartition par âge x sexe sur l'ensemble des clients.
-- Ajouter la colonne gender à la table client
alter table client add gender character(10);
update client set gender = (case when lower(civilite) = 'monsieur' then 'male'
							when lower(civilite) = 'madame' then 'female'
							when civilite = 'Mr' then 'male'
							when civilite = 'Mme' then 'female' end);
-- Ajouter la colonne age à la table client
alter table client add age real;
update client set age = 2018 - extract(year from datenaissance);
-- Ajouter la colonne qui rassemble age et gender
alter table client add age_sex character(20);
update client set age_sex = concat(gender, age);
-- Ne pas tenir compte des valeurs inférieures à 18 et supérieures à 100
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
```
### Données de la requête SQL
```{r}
head(X1c)
```
### Visualisation
```{r message=FALSE, warning=FALSE}
fill <- c("#40b8d0", "#b2d183")
ggplot() +
geom_bar(aes(y = pct, x = age, fill = as.factor(gender)), data = X1c, stat = "identity") +
  geom_text(data = X1c, aes(x = age, y = pct, label = ''), colour = "black") +
  theme(legend.position = "top", legend.direction = "horizontal", legend.title = element_blank()) +
  theme(axis.text.x = element_text(angle = 90, hjust = 1)) + 
  labs(x = "Age x Sex", y = "Pourcentage") +
  ggtitle("Répartition par âge x sexe") +
  theme(plot.title = element_text(hjust = 0.5)) + 
  scale_fill_manual(values = fill) +
  theme(axis.line = element_line(size=1, colour = "black"),
        panel.grid.major = element_line(colour = "#d3d3d3"), panel.grid.minor = element_blank(),
        panel.border = element_blank(), panel.background = element_blank()) +
  theme(plot.title = element_text(size = 14, family = "Tahoma", face = "bold"),
        text=element_text(family = "Tahoma"),
        axis.text.x = element_text(colour = "black", size = 10),
        axis.text.y = element_text(colour = "black", size = 10))
```
```{r message=FALSE, warning=FALSE}
fill <- c("#40b8d0", "#b2d183")
ggplot() +
geom_bar(aes(y = pct, x = cut(age,10), fill = as.factor(gender)), data = X1c, stat = "identity") +
  geom_text(data = X1c, aes(x = cut(age,10), y = pct, label = ''), colour = "black") +
  theme(legend.position = "top", legend.direction = "horizontal", legend.title = element_blank()) +
  theme(axis.text.x = element_text(angle = 90, hjust = 1)) + 
  labs(x = "Age x Sex", y = "Pourcentage") +
  ggtitle("Répartition par âge x sexe") +
  theme(plot.title = element_text(hjust = 0.5)) + 
  scale_fill_manual(values = fill) +
  theme(axis.line = element_line(size=1, colour = "black"),
        panel.grid.major = element_line(colour = "#d3d3d3"), panel.grid.minor = element_blank(),
        panel.border = element_blank(), panel.background = element_blank()) +
  theme(plot.title = element_text(size = 14, family = "Tahoma", face = "bold"),
        text=element_text(family = "Tahoma"),
        axis.text.x = element_text(colour = "black", size = 10),
        axis.text.y = element_text(colour = "black", size = 10))
```
> Il y a plus de clients femmes que de clients hommes. La plupart des clients ont entre 26 et 75 ans. Les client âgés entre 50 à 59 ans représentent 20% de l'ensemble de la population client (avec une répartition femme ~ 13% et homme ~ 6%). Les clients jeunes (moins de 26 ans) ne représentent que 2% de la population.

# II. Etude par magasin
## 1. Résultat par magasin
### Requête SQL
```{sql}
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
-- Nombre de clients actifs sur N-2: Nb_client_actif_2016
		select mag_code as codesociete, count(distinct idclient) as Nb_client_actif_2016 from entete_ticket
		where extract(year from tic_date) = 2016
		group by mag_code
	) as temp8
	join
	(
-- Nombre de clients actifs sur N-1: Nb_client_actif_2017
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
```
### Données de la requête SQL
```{r}
head(X2a)
```
### Visualisation
```{r}
X2a <- X2a %>% adorn_totals("row")
X2a[67,9] <- "moyen"

# couleur evolution
posneg <- formatter("span", style = x ~ style(color = ifelse(x > 0, "green", ifelse(x < 0, "red", "black"))))

# Couleur indice
indice <- formatter("span", style = x ~ style(color = ifelse(x == "positive", "green", ifelse(x == "negative", "red", "black"))))

# Icone evolution
arrow <- formatter("span", style = x ~ style(font.weight = "bold", color = ifelse(x > 0, "green", ifelse(x < 0, "red", "black"))), x ~ icontext(ifelse(x > 0, "arrow-up", ifelse(x < 0, "arrow-down", "-"))))

# Formater uniquement les n-1
myfun <- function (x) {A <- color_bar (x)
function (y){
  c(A(y[-length(y)]), y[length(y)])
  }
}

X2a$sign <- as.numeric(ifelse(X2a$indice_evol == "positive", 1, ifelse(X2a$indice_evol == "negative", -1, 0)))

formattable(X2a, list(pct_nb_actif = posneg, 
                      dif_ttc = posneg, 
                      indice_evol = indice,
                      nb_client = myfun("lightgreen"),
                      sign = arrow))
```
> Ce tableau présente l'évolution de deux indicateurs : le nombre de clients actifs et le chiffre d'affaires par magasin. Si l'évolution du nombre de client et du du CA sont tous les deux positifs, l'indice_evol affichera une évolution globale « positive ». Si l'évolution du nombre de client et du CA sont tous les deux négatifs, l'indice_evol affichera une évolution globale « négative ». Sinon, il affichera un comportement « moyen ».

## 2. Distance client / magasin
### Requête SQL
```{sql}
-- Importer la base de donnée: Insee
-- Load Data: insee
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

-- La fonction customisée pour calculer la distance étant données les valeurs longtitude et latitude
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

-- Créer table qui combine client, magasin et leur long and lat
-- Extraire le longtitude et latitude pour le client et le magasin et calculer la distance en utilisant la fonction customisée : calculate_distance
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
```
### Données de la requête SQL
```{r}
head(X2b)
```
### Visualisation
```{r message=FALSE, warning=FALSE}
temp <- ddply(X2b,~dist_km_interval, summarise, count_client = length(unique(idclient_new)))
temp$dist_km_interval <- factor(temp$dist_km_interval,levels = c("[0;5]", "(5;10]", "(10;20]", "(20;50]",">50"))
ggplot(temp) + 
  geom_bar(aes(x = dist_km_interval, y = count_client), stat = "identity", fill = '#b2d183') +
  geom_text(data = temp, aes(x = dist_km_interval, y = count_client, label = count_client), vjust = 1.6, color = "black", size = 3.5) +
  labs(x = "Distance entre client et magasin (km)", y = "Nombre des clients") +
  theme(legend.position = "bottom", legend.direction = "horizontal", legend.title = element_blank()) +
  ggtitle("Nombre de clients selon distance domicile-magasin") +
  theme(plot.title = element_text(hjust = 0.5)) + 
  theme(axis.line = element_line(size=1, colour = "black"),
        panel.grid.major = element_line(colour = "#d3d3d3"), panel.grid.minor = element_blank(),
        panel.border = element_blank(), panel.background = element_blank()) +
  theme(plot.title = element_text(size = 14, family = "Tahoma", face = "bold"),
        text=element_text(family = "Tahoma"),
        axis.text.x = element_text(colour = "black", size = 10),
        axis.text.y = element_text(colour = "black", size = 10))
```
> La plupart des clients habitent dans un rayon de moins de 20 kms autour du magasin.
Cependant, il y a 143 347 clients qui sont domiciliés à plus de 50 km du magasin.

# III. Etude par univers
## 1. N-2 / N-1 évolution du CA par univers
### Requête SQL
```{sql}
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
```
### Données de la requête SQL
```{r}
head(X3a)
```
### Visualisation
```{r message=FALSE, warning=FALSE}
ggplot(X3a) + 
  geom_bar(aes(x = codeunivers, y = diff_ca), stat = "identity", fill = '#40b8d0') +
  geom_text(data = X3a, aes(x = codeunivers, y = diff_ca, label = round(diff_ca,2)), vjust = 1.2, color = "black", size = 3.5) +
  labs(x = "Univers", y = "Chiffre d'affaires") +
  theme(legend.position = "bottom", legend.direction = "horizontal", legend.title = element_blank()) +
  ggtitle("N-2 / N-1 évolution du CA par univers") +
  theme(plot.title = element_text(hjust = 0.5)) + 
  theme(axis.line = element_line(size=1, colour = "black"),
        panel.grid.major = element_line(colour = "#d3d3d3"), panel.grid.minor = element_blank(),
        panel.border = element_blank(), panel.background = element_blank()) +
  theme(plot.title = element_text(size = 14, family = "Tahoma", face = "bold"),
        text=element_text(family = "Tahoma"),
        axis.text.x = element_text(colour = "black", size = 10),
        axis.text.y = element_text(colour = "black", size = 10))
```
> Le chiffre d'affaires pour les univers U3 et U2 diminue (de 2016 à 2017) avec respectivement 4 106 008 et 1 215 430 de baisse de CA. Les autres univers connaissent une évolution positive de leur CA (U0: augmentation de 825 209,  U1: augmentation de 963 772 et U4: augmentation de 981 171)

## 2. Top 5 des familles les plus rentables par univers
### Requête SQL
```{sql}
select *
from
(select codeunivers, codesousfamille, rentab, 
       row_number() over (partition by codeunivers order by rentab desc) as temp_rank 
 from 
 (select codeunivers, codesousfamille, sum(margesortie) as rentab
  from ref_article inner join lignes_ticket on ref_article.codearticle = lignes_ticket.idarticle
  group by codesousfamille, codeunivers) as temp1) as temp2
  where temp_rank <= 5;
```
### Données de la requête SQL
```{r}
head(X3b,10)
```
### Visualisation
```{r}
colnames(X3b) <- c("univers", "famille", "rentabilite", "rang")
my_colorbar <- function(col1 = "lightgreen", col2 = "red", ...){
  formatter("span",
            style = function(x) style(
              display = "inline-block",
              float = ifelse(x >= 0, "right", "left"),
              "text-align" = ifelse(x >= 0, "right", "left"),
              "margin-left" = ifelse(x >= 0, "0%", "50%"),
              "margin-right" = ifelse(x >= 0,"50%", "0%"),
              "border-radius" = "4px",
              "background-color" = ifelse(x >= 0, col1, col2),
              width = percent(0.5*proportion(abs(as.numeric(x)), ...))
            ))}
formattable(X3b, list(rentabilite = my_colorbar()))
```

> Nous constatons ici que l'univers qui rapporte le plus est U3 (20 676 748 euros) suivi de U1, U4, U2 et enfin U0. Ce dernier comportant des familles dégageant des marges très disparates.
L'univers "coupon" est bien entendu négatif puisqu'il aggrège les montants des réductions appliquées en magasin. 
