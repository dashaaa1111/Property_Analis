/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 *
 * Автор:
 * Дата:
*/



-- Задача 1: Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:

-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:

-- Продолжите запрос здесь
-- Используйте id объявлений (СТЕ filtered_id), которые не содержат выбросы при анализе данных
WITH limits AS ( 
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
filtered_id AS (
    SELECT f.id
    FROM real_estate.flats f, limits l
    WHERE 
        f.total_area < l.total_area_limit
        AND (f.rooms < l.rooms_limit OR f.rooms IS NULL)
        AND (f.balcony < l.balcony_limit OR f.balcony IS NULL)
        AND (
            (f.ceiling_height < l.ceiling_height_limit_h
             AND f.ceiling_height > l.ceiling_height_limit_l)
            OR f.ceiling_height IS NULL
        )
),
ad_cat AS (
    SELECT 
        f.id,
        f.total_area,
        f.rooms,
        f.floors_total,
        f.living_area,
        f.floor,
        f.balcony,
        -- регион
        CASE 
            WHEN c.city = 'Санкт-Петербург' THEN 'Санкт-Петербург'
            ELSE 'ЛенОбл'
        END AS region,
        -- категория времени
        CASE  
           when a.days_exposition>= 1 and days_exposition <= 30 then 'до месяца'
           when a.days_exposition>= 31 and days_exposition <= 90 then 'от месяца до трех месяцев'
           when a.days_exposition>= 91 and days_exposition <= 180 then 'от трех месяцев до полугода'
           when a.days_exposition>= 181 then 'более полугода'
            ELSE null
        END AS cat_type,
        a.last_price / f.total_area AS avg_price,
        COUNT(f.id) OVER (PARTITION BY 
            CASE WHEN c.city = 'Санкт-Петербург' THEN 'Санкт-Петербург' ELSE 'ЛенОбл' END
        ) AS count_region_flat
    FROM real_estate.flats f
    JOIN real_estate.advertisement a ON f.id = a.id
    JOIN real_estate.city c ON f.city_id = c.city_id
    JOIN real_estate.type t ON f.type_id = t.type_id
    WHERE 
        f.id IN (SELECT id FROM filtered_id)
        AND t.type = 'город'
        AND a.first_day_exposition >= '2015-01-01'
        AND a.first_day_exposition < '2019-01-01'    
)
SELECT 
    region,
    cat_type,
    COUNT(id) AS total_id,
    ROUND(COUNT(id)::numeric / MAX(count_region_flat)::numeric, 2) AS share_of_region,
    AVG(avg_price)::NUMERIC(10,2) AS avg_m_price,
    AVG(total_area)::NUMERIC(5,2) AS avg_area,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms) AS med_rooms,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY balcony) AS med_balcony,
    PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY floor) AS med_floor
FROM ad_cat
where cat_type is not null
GROUP BY region, cat_type
ORDER BY 
    region,
    CASE cat_type 
        WHEN 'от одного до трёх месяцев' THEN 1
        WHEN 'от трёх месяцев до полугода' THEN 2
        WHEN 'более полугода' THEN 3
        ELSE 4
    END;


-- Задача 2: Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:

-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:

-- Продолжите запрос здесь
-- Используйте id объявлений (СТЕ filtered_id), которые не содержат выбросы при анализе данных

WITH limits AS (
    SELECT
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area)     AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms)          AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony)        AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
filtered_id AS (
    SELECT f.id
    FROM real_estate.flats f
    CROSS JOIN limits l
    WHERE
        (f.total_area < l.total_area_limit OR f.total_area IS NULL)  
        AND (f.rooms < l.rooms_limit OR f.rooms IS NULL)
        AND (f.balcony < l.balcony_limit OR f.balcony IS NULL)
        AND (
            (f.ceiling_height < l.ceiling_height_limit_h AND f.ceiling_height > l.ceiling_height_limit_l)
            OR f.ceiling_height IS NULL
        )
),
period_id AS (
    select
        f.id,
        a.last_price / f.total_area AS cost_per_m,
        f.total_area,
        TO_CHAR(a.first_day_exposition, 'TMMonth') AS month_exposition,
        EXTRACT(MONTH FROM a.first_day_exposition) AS month_exp_num,
        TO_CHAR(a.first_day_exposition + a.days_exposition::int, 'TMMonth') AS month_removing,
        EXTRACT(MONTH FROM a.first_day_exposition + a.days_exposition::int) AS month_rem_num
    FROM real_estate.advertisement a
    JOIN real_estate.flats f ON a.id = f.id
    JOIN real_estate.city c ON f.city_id = c.city_id
    JOIN real_estate.type t ON f.type_id = t.type_id
    WHERE
        t.type = 'город'
        AND a.first_day_exposition >= '2015-01-01'
        AND a.first_day_exposition < '2019-01-01'
        -- УБРАНО: days_exposition IS NOT NULL
        AND f.id IN (SELECT id FROM filtered_id)
),
exp_statistic AS (
    SELECT
        month_exposition,
        month_exp_num,
        COUNT(id)          AS exp_count_id,
        AVG(cost_per_m)    AS avg_cost,
        AVG(total_area)    AS avg_area
    FROM period_id
    GROUP BY month_exposition, month_exp_num
),
rem_statistic AS (
    SELECT
        month_removing,
        month_rem_num,
        COUNT(id)          AS rem_count_id,
        AVG(cost_per_m)    AS avg_cost,
        AVG(total_area)    AS avg_area
    FROM period_id
    WHERE month_rem_num IS NOT NULL   -- фильтрация ТОЛЬКО здесь
    GROUP BY month_removing, month_rem_num
)
SELECT
    COALESCE(es.month_exposition, rs.month_removing) AS month,
    es.exp_count_id,
    es.avg_cost::NUMERIC(10,2),
    es.avg_area::NUMERIC(5,1),
    rs.rem_count_id,
    rs.avg_cost::NUMERIC(10,2),
    rs.avg_area::NUMERIC(5,1)
FROM exp_statistic es
FULL OUTER JOIN rem_statistic rs
    ON es.month_exp_num = rs.month_rem_num
ORDER BY COALESCE(es.month_exp_num, rs.month_rem_num);