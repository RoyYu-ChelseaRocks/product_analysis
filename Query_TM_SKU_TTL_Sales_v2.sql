with
trans_fact as
    (
        select
        tr.kyid,
        date(tr.payment_confirm_time) as payment_confirm_date,
        cm1.cur_lego_year as trans_lego_year,
        cm1.cur_lego_month as trans_lego_month,
        tr.payment_confirm_time,
        tr.parent_order_id,
        tr.piece_cnt,
        tr.order_rrp_amount,
        tr.lego_sku_id,
        pi.cn_line,
        pi.lego_sku_name_cn,
        case
        when adsku.lego_sku_id is not null then 'y'
        else 'n' end as adult_sku_flag,
        case
        when fsku.lego_sku_id is not null then 'y'
        else 'n' end as focus_sku_flag,
        case when cm1.cur_lego_year in (2022, 2023) then concat(cast(cm1.cur_lego_year as varchar), '_fy') else 'exception' end as trans_period_fy,
        case when (date(tr.payment_confirm_time) >= '2023-01-02' and date(tr.payment_confirm_time) < '2023-02-22')
            or (date(tr.payment_confirm_time) >= '2024-01-01' and date(tr.payment_confirm_time) < '2024-02-21')
            then concat(cast(cm1.cur_lego_year as varchar), '_ytd') else 'exception' end trans_period_ytd
        from edw.f_oms_order_dtl_upd as tr
        left join edw.d_dl_product_info_latest as pi
        on tr.lego_sku_id = pi.lego_sku_id
        left join tutorial.lego_calendar_mapping_roy_v2 as cm1
        on date(tr.payment_confirm_time) = date(cm1.cur_date)
        left join tutorial.adult_sku_list_roy_v2 as adsku
        on cast(tr.lego_sku_id as varchar) = cast(adsku.lego_sku_id as varchar)
        left join tutorial.focus_sku_list_roy as fsku
        on cast(tr.lego_sku_id as varchar) = cast(fsku.lego_sku_id as varchar)
        and date(fsku.start_date) <= date(tr.payment_confirm_time)
        and date(fsku.end_date) >= date(tr.payment_confirm_time)
        where 1 = 1
        and tr.is_delivered = 'Y'
        and tr.is_gwp_via_gmv = 'N'
        and tr.lego_sku_gmv_price >= 59
        and tr.lego_sku_rrp_price > 0
        and tr.platformid = 'taobao'
        and date(tr.payment_confirm_time) < '2024-02-21' -- 2024 Jan lego month end date
        and tr.kyid is not null
    )

---------------------------------------------------------------

-- full year sales by cn line
select
trans_period_fy,
cn_line,
sum(order_rrp_amount) as total_sales
from trans_fact
where 1 = 1
and trans_period_fy in ('2022_fy', '2023_fy')
group by
trans_period_fy,
cn_line
order by
trans_period_fy,
cn_line

-- Jan ytd year sales by cn line
select
trans_period_ytd,
cn_line,
sum(order_rrp_amount) as total_sales
from trans_fact
where 1 = 1
and trans_period_ytd in ('2023_ytd', '2024_ytd')
group by
trans_period_ytd,
cn_line
order by
trans_period_ytd,
cn_line

-- full year sales by focus sku id
select
trans_period_fy,
lego_sku_id,
sum(order_rrp_amount) as total_sales
from trans_fact
where 1 = 1
and trans_period_fy in ('2022_fy', '2023_fy')
and focus_sku_flag = 'y'
group by
trans_period_fy,
lego_sku_id
order by
trans_period_fy,
lego_sku_id

-- Jan YTD sales by focus sku id
select
trans_period_ytd,
lego_sku_id,
sum(order_rrp_amount) as total_sales
from trans_fact
where 1 = 1
and trans_period_ytd in ('2023_ytd', '2024_ytd')
and focus_sku_flag = 'y'
group by
trans_period_ytd,
lego_sku_id
order by
trans_period_ytd,
lego_sku_id

-- full year sales by adult& kids line
select
trans_period_fy,
adult_sku_flag,
sum(order_rrp_amount) as total_sales
from trans_fact
where 1 = 1
and trans_period_fy in ('2022_fy', '2023_fy')
group by
trans_period_fy,
adult_sku_flag
order by
trans_period_fy,
adult_sku_flag

-- Jan YTD sales by adult& kids line
select
trans_period_ytd,
adult_sku_flag,
sum(order_rrp_amount) as total_sales
from trans_fact
where 1 = 1
and trans_period_ytd in ('2023_ytd', '2024_ytd')
group by
trans_period_ytd,
adult_sku_flag
order by
trans_period_ytd,
adult_sku_flag

-- full year sales
select
trans_period_fy,
sum(order_rrp_amount) as total_sales
from trans_fact
where 1 = 1
and trans_period_fy in ('2022_fy', '2023_fy')
group by
trans_period_fy
order by
trans_period_fy

-- Jan YTD sales
select
trans_period_ytd,
sum(order_rrp_amount) as total_sales
from trans_fact
where 1 = 1
and trans_period_ytd in ('2023_ytd', '2024_ytd')
group by
trans_period_ytd
order by
trans_period_ytd