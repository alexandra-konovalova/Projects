--Имя: Коновалова Александра
--Дата: 22.01.25-26.01.25
--Задача 1. Время активности объявлений 
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
filtered_data AS (
SELECT CASE 
	WHEN c.city = 'Санкт-Петербург' THEN 'Санкт-Петербург'
	ELSE 'ЛенОбл'
    END AS region,
       CASE
	   WHEN days_exposition IS NULL THEN 'Не продано'
       WHEN a.days_exposition >= 1 AND a.days_exposition <=30 THEN 'Месяц'
       WHEN a.days_exposition >= 31 AND a.days_exposition <=90 THEN 'Квартал'
       WHEN a.days_exposition >= 91 AND a.days_exposition <=180 THEN 'Полгода'
       ELSE 'Больше полугода'
       END AS period_exposition,
       COUNT (f.id) AS count_id,
       ROUND (AVG (f.total_area::numeric),2) AS avg_area, 
       ROUND(AVG(a.last_price::numeric),2) AS avg_price,
       PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY f.total_area) AS total_area_limit,
       PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY f.rooms) AS rooms_limit,
       PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY f.balcony) AS balcony_limit,
       PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY f.ceiling_height) AS ceiling_height_limit,
       PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY f.floors_total) AS total_floors_limit,
       ROUND (AVG (f.parks_around3000::numeric),1) AS avg_parks
FROM real_estate.flats AS f
LEFT JOIN real_estate.city AS c USING (city_id)
LEFT JOIN real_estate.advertisement AS a USING (id)
LEFT JOIN real_estate.TYPE AS t USING (type_id)
WHERE id IN (SELECT * FROM filtered_id) AND t.type = 'город'
GROUP BY region, period_exposition)
SELECT region, period_exposition, count_id, avg_area, avg_price, ROUND (avg_price/avg_area,2) AS price_kv, total_area_limit, rooms_limit, balcony_limit, ceiling_height_limit, total_floors_limit, avg_parks
FROM filtered_data
ORDER BY region DESC, count_id DESC;

--Задача 2. Сезонность объявлений
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
filtered_id AS(
    SELECT id
    FROM real_estate.flats 
    LEFT JOIN real_estate.advertisement AS a USING (id)
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
            AND EXTRACT(YEAR FROM a.first_day_exposition) IN ('2015','2016','2017','2018')
    ),
first_month AS (SELECT COUNT (f.id) AS count_adv, AVG (a.last_price::numeric) AS first_avg_price, AVG (f.total_area::numeric) AS first_avg_area, EXTRACT(MONTH FROM a.first_day_exposition) AS month_first_day_exposition
FROM real_estate.flats AS f
LEFT JOIN real_estate.advertisement AS a USING (id)
LEFT JOIN real_estate.TYPE AS t USING (type_id)
WHERE id IN (SELECT * FROM filtered_id) AND EXTRACT(MONTH FROM a.first_day_exposition) IS NOT NULL AND t.TYPE = 'город'
GROUP BY month_first_day_exposition),
last_month AS (SELECT COUNT (f.id) AS count_sale, AVG (a.last_price::numeric) AS last_avg_price, AVG (f.total_area::numeric) AS last_avg_area, EXTRACT(MONTH FROM a.first_day_exposition+a.days_exposition::int) AS month_last_day_exposition
FROM real_estate.flats AS f
LEFT JOIN real_estate.advertisement AS a USING (id)
LEFT JOIN real_estate.TYPE AS t USING (type_id)
WHERE id IN (SELECT * FROM filtered_id) AND EXTRACT(MONTH FROM a.first_day_exposition+a.days_exposition::int) IS NOT NULL AND t.TYPE = 'город'
GROUP BY month_last_day_exposition)
SELECT f.month_first_day_exposition, f.count_adv, DENSE_RANK () OVER (ORDER BY f.count_adv DESC) AS rank_avg,
l.month_last_day_exposition,l.count_sale, DENSE_RANK () OVER (ORDER BY l.count_sale DESC) AS rank_sale, 
ROUND (f.first_avg_area::numeric,2) AS first_avg_area, ROUND (f.first_avg_price/f.first_avg_area,2) AS first_avg_price_kv,
ROUND (l.last_avg_area::numeric,2) AS last_avg_area, ROUND (l.last_avg_price/l.last_avg_area,2) AS last_avg_price_kv
FROM first_month AS f
LEFT JOIN last_month AS l ON f.month_first_day_exposition = l.month_last_day_exposition;

--Задача 3. Анализ рынка недвижимости Ленобласти
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
avg_sale AS (SELECT 
c.city AS city_name,
COUNT (f.id) AS count_sale 
FROM real_estate.flats AS f
LEFT JOIN real_estate.city AS c USING (city_id)
LEFT JOIN real_estate.advertisement AS a USING (id)
WHERE id IN (SELECT * FROM filtered_id) AND days_exposition IS NOT NULL
GROUP BY c.city),
filtered_data AS (SELECT c.city,
       COUNT (f.id) AS count_avg,
       ROUND (AVG (f.total_area::numeric),2) AS avg_area, 
       ROUND(AVG(a.last_price::numeric),2) AS avg_price,
       PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY f.total_area) AS total_area_limit,
       PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY f.rooms) AS rooms_limit,
       PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY f.balcony) AS balcony_limit,
       PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY f.ceiling_height) AS ceiling_height_limit,
       PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY f.floors_total) AS total_floors_limit,
       ROUND (AVG (a.days_exposition::numeric),2) AS avg_days_exposition
FROM real_estate.flats AS f
LEFT JOIN real_estate.advertisement AS a USING (id)
LEFT JOIN real_estate.city AS c USING (city_id)
WHERE id IN (SELECT * FROM filtered_id) AND  c.city <> 'Санкт-Петербург'
GROUP BY c.city)
SELECT f.city, count_avg, count_sale, ROUND (count_sale/count_avg::NUMERIC,2) AS part_sale_flat, avg_area, avg_price, ROUND (avg_price/avg_area,2) AS price_kv, avg_days_exposition, total_area_limit, rooms_limit, balcony_limit, ceiling_height_limit, total_floors_limit
FROM filtered_data AS f
LEFT JOIN avg_sale AS a ON a.city_name = f.city
WHERE count_avg >= 50 
ORDER BY count_avg DESC
LIMIT 10;


