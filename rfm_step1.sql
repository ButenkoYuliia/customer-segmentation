-- =====================================================
-- RFM-сегментация клиентов — Шаг 1: таблица RFM
-- Датасет: DA (BigQuery)
-- Замени `DA.` на полный путь своего проекта,
-- например `data-analytics-mate.DA.`
-- =====================================================

-- Запрос 1. RFM-показатели для каждого клиента
WITH orders AS (
  SELECT
    acs.account_id,          -- кто купил
    s.date,                  -- когда купил
    o.ga_session_id,         -- в какой сессии (= один заказ)
    p.price                  -- сколько стоил товар
  FROM `DA.order` AS o
  JOIN `DA.product` AS p
    ON o.item_id = p.item_id
  JOIN `DA.session` AS s
    ON o.ga_session_id = s.ga_session_id
  JOIN `DA.account_session` AS acs     -- только зарегистрированные клиенты
    ON o.ga_session_id = acs.ga_session_id
)
SELECT
  account_id,
  -- R: сколько дней прошло с последней покупки до конца периода
  DATE_DIFF((SELECT MAX(date) FROM `DA.session`), MAX(date), DAY) AS recency_days,
  -- F: сколько раз покупал (число сессий с заказом)
  COUNT(DISTINCT ga_session_id) AS frequency,
  -- M: сколько всего потратил
  ROUND(SUM(price), 2) AS monetary
FROM orders
GROUP BY account_id
ORDER BY monetary DESC;


-- Запрос 2. Проверка: как распределены покупки
-- (сколько клиентов купили 1 раз, 2 раза, 3 раза ...)
WITH rfm AS (
  SELECT
    acs.account_id,
    COUNT(DISTINCT o.ga_session_id) AS frequency
  FROM `DA.order` AS o
  JOIN `DA.account_session` AS acs
    ON o.ga_session_id = acs.ga_session_id
  GROUP BY acs.account_id
)
SELECT
  frequency,
  COUNT(*) AS clients
FROM rfm
GROUP BY frequency
ORDER BY frequency;
