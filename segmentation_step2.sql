-- =====================================================
-- Сегментация клиентов — Шаг 2: таблица признаков
-- Одна строка = один клиент (account)
-- Датасет: data-analytics-mate.DA
-- =====================================================

-- 1) Заказ клиента: сумма, число товаров, число категорий
WITH order_features AS (
  SELECT
    acs.account_id,
    MIN(s.date)                      AS order_date,
    ROUND(SUM(p.price), 2)           AS order_sum,
    COUNT(*)                         AS items_cnt,
    COUNT(DISTINCT p.category)       AS categories_cnt,
    ROUND(AVG(p.price), 2)           AS avg_item_price,
    ANY_VALUE(o.ga_session_id)       AS ga_session_id
  FROM `data-analytics-mate.DA.order` AS o
  JOIN `data-analytics-mate.DA.product` AS p
    ON o.item_id = p.item_id
  JOIN `data-analytics-mate.DA.session` AS s
    ON o.ga_session_id = s.ga_session_id
  JOIN `data-analytics-mate.DA.account_session` AS acs
    ON o.ga_session_id = acs.ga_session_id
  GROUP BY acs.account_id
),

-- 2) Email-вовлечённость: сколько писем получил / открыл / перешёл
email_features AS (
  SELECT
    es.id_account                         AS account_id,
    COUNT(DISTINCT es.id_message)         AS emails_sent,
    COUNT(DISTINCT eo.id_message)         AS emails_opened,
    COUNT(DISTINCT ev.id_message)         AS emails_visited
  FROM `data-analytics-mate.DA.email_sent` AS es
  LEFT JOIN `data-analytics-mate.DA.email_open` AS eo
    ON es.id_message = eo.id_message
  LEFT JOIN `data-analytics-mate.DA.email_visit` AS ev
    ON es.id_message = ev.id_message
  GROUP BY es.id_account
)

-- 3) Собираем всё в одну таблицу
SELECT
  o.account_id,
  o.order_date,
  o.order_sum,
  o.items_cnt,
  o.categories_cnt,
  o.avg_item_price,

  COALESCE(e.emails_sent, 0)    AS emails_sent,
  COALESCE(e.emails_opened, 0)  AS emails_opened,
  COALESCE(e.emails_visited, 0) AS emails_visited,
  ROUND(SAFE_DIVIDE(e.emails_opened,  e.emails_sent), 3) AS open_rate,
  ROUND(SAFE_DIVIDE(e.emails_visited, e.emails_sent), 3) AS visit_rate,

  a.is_verified,
  a.is_unsubscribed,
  a.send_interval,

  -- описательные поля (не для модели, а чтобы потом описать сегменты)
  sp.device,
  sp.channel,
  sp.continent,
  sp.country
FROM order_features AS o
LEFT JOIN email_features AS e
  ON o.account_id = e.account_id
LEFT JOIN `data-analytics-mate.DA.account` AS a
  ON o.account_id = a.id
LEFT JOIN `data-analytics-mate.DA.session_params` AS sp
  ON o.ga_session_id = sp.ga_session_id
ORDER BY o.order_sum DESC;
