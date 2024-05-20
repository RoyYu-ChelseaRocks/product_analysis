with
order_fact as
    (
        select
        dc.city as delivery_city,
        coalesce(mct.city_type, '4_others') as city_type,
        tr.order_rrp_amount,
        date(tr.payment_confirm_time) as payment_confirm_date,
        case when cm1.cur_lego_year in (2022, 2023) then concat(cast(cm1.cur_lego_year as varchar), '_fy') else 'exception' end as trans_period_fy,
        case when (date(tr.payment_confirm_time) >= '2023-01-02' and date(tr.payment_confirm_time) < '2023-02-22')
            or (date(tr.payment_confirm_time) >= '2024-01-01' and date(tr.payment_confirm_time) < '2024-02-21')
            then concat(cast(cm1.cur_lego_year as varchar), '_ytd') else 'exception' end trans_period_ytd
        from edw.f_oms_order_dtl_upd as tr
        left join
            (
                select
                parent_order_id,
                city
                from edw.f_oms_order_upd
                where 1 = 1
                and date(payment_confirm_time) < '2024-02-21'
                group by
                parent_order_id,
                city
            ) as dc -- delivery city
        on tr.parent_order_id = dc.parent_order_id
        left join tutorial.mkt_city_type_roy_v1 as mct
        on dc.city = mct.city_chn
        left join tutorial.lego_calendar_mapping_roy_v2 as cm1
        on date(tr.payment_confirm_time) = date(cm1.cur_date)
        where 1 = 1
        and date(tr.payment_confirm_time) < '2024-02-21'
        and tr.is_delivered = 'Y'
        and tr.is_gwp_via_gmv = 'N'
        and tr.lego_sku_gmv_price >= 59
        and tr.lego_sku_rrp_price > 0
        and tr.platformid = 'taobao'
    )

-----------------------------

select
trans_period_fy,
city_type,
sum(order_rrp_amount) as total_sales
from order_fact
where 1 = 1
and trans_period_fy in ('2022_fy', '2023_fy')
group by
trans_period_fy,
city_type
order by
trans_period_fy,
city_type


select
trans_period_ytd,
city_type,
sum(order_rrp_amount) as total_sales
from order_fact
where 1 = 1
and trans_period_ytd in ('2023_ytd', '2024_ytd')
group by
trans_period_ytd,
city_type
order by
trans_period_ytd,
city_type


select
trans_period_fy,
city_type,
delivery_city,
sum(order_rrp_amount) as total_sales
from order_fact
where 1 = 1
and trans_period_fy in ('2022_fy', '2023_fy')
and city_type <> '4_others'
group by
trans_period_fy,
city_type,
delivery_city
order by
trans_period_fy,
city_type,
delivery_city


select
trans_period_ytd,
city_type,
delivery_city,
sum(order_rrp_amount) as total_sales
from order_fact
where 1 = 1
and trans_period_ytd in ('2023_ytd', '2024_ytd')
and city_type <> '4_others'
group by
trans_period_ytd,
city_type,
delivery_city
order by
trans_period_ytd,
city_type,
delivery_city