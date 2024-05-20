drop table if exists tutorial.dy_sku_trans_roy_v2; -- for the 1st time of table creation
create table tutorial.dy_sku_trans_roy_v2 as -- for the 1st time of table creation

-- 2022全年 = 2022-01-03 to 2023-01-01
-- 2023全年 = 2023-01-02 to 2023-12-31
-- 2023 Jan YTD = 2023-01-02 to 2023-01-29
-- 2024 Jan YTD = 2024-01-01 to 2024-01-28

with
annual_member_shopper as
    (
        select
        tr.eff_member_detail_id,
        cm1.cur_lego_year as trans_lego_year
        from tutorial.dy_trans_sku_ext as tr
        left join tutorial.lego_calendar_mapping_roy_v2 as cm1
        on date(tr.date_id) = date(cm1.cur_date)
        where 1 = 1
        and tr.mbr_purchase_flag_ext = 1
        and tr.eff_member_detail_id is not null
        and tr.date_id  < '2024-02-21' -- start date
        group by
        tr.eff_member_detail_id,
        cm1.cur_lego_year
    ),

payment_time_fact as
    (
        select
        a.parent_order_id,
        min(a.payment_confirm_time) as payment_confirm_time
        from
            (
                select
                payment_confirm_time,
                parent_order_id
                from edw.f_oms_order_dtl_upd
                where 1 = 1
                and is_delivered = 'Y'
                and is_gwp = 'N'
                and platformid = 'douyin'
                and is_gwp = 'N'
                and date(payment_confirm_time) < current_date

                union all

                select
                payment_confirm_time,
                parent_order_id
                from edw.f_oms_order_dtl_dy_b2b
                where 1 = 1
                and is_delivered = 'Y'
                and is_gwp = 'N'
                and platformid = 'douyin'
                and is_gwp = 'N'
                and date(payment_confirm_time) < current_date
            ) as a
        group by
        a.parent_order_id
    ),

member_parent_order_rank as
    (
        select
        a.*,
        row_number() over (partition by a.eff_member_detail_id order by a.porder_time asc) as rnk_in_life
        from
            (
                select
                tr.eff_member_detail_id,
                tr.parent_order_id,
                min(ptf.payment_confirm_time) as porder_time
                from tutorial.dy_trans_sku_ext as tr
                left join payment_time_fact as ptf
                on tr.parent_order_id = ptf.parent_order_id
                where 1 = 1
                and tr.mbr_purchase_flag_ext = 1
                and tr.eff_member_detail_id is not null
                and tr.date_id < '2024-02-21' -- start date
                group by
                tr.eff_member_detail_id,
                tr.parent_order_id
            ) as a
    )

--------------------------------------------

select
tr.eff_member_detail_id as kyid,
tr.date_id as payment_confirm_date,
cm1.cur_lego_year as trans_lego_year,
cm1.cur_lego_month as trans_lego_month,
tr.parent_order_id,
mpor.rnk_in_life,
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

pi.rsp,
case
when adult_sku_flag = 'y' and rsp < 499 then 'lpp'
when adult_sku_flag = 'y' and rsp >= 499 and rsp < 1600 then 'mpp'
when adult_sku_flag = 'y' and rsp >= 1600 then 'hpp'
when adult_sku_flag = 'n' and rsp < 399 then 'lpp'
when adult_sku_flag = 'n' and rsp >= 399 and rsp < 1000 then 'mpp'
when adult_sku_flag = 'n' and rsp >= 1000 then 'hpp'
else 'exception' end as rsp_tier,

case when tr.date_id >= '2024-01-01' and tr.date_id < '2024-02-21' then concat(cast(cm1.cur_lego_year as varchar), '_ytd') else 'exception' end trans_period_ytd,

tr.belong_date_ext,
cm2.cur_lego_year as reg_lego_year,
cm2.cur_lego_month as reg_lego_month,

case -- cm1 refers to trans lego year, cm2 refers to TM registration year, ams.kyid refers to memeber shoppers from the previous year
when cm2.cur_lego_year = cm1.cur_lego_year then 'new'
when cm2.cur_lego_year < cm1.cur_lego_year and ams.eff_member_detail_id is not null then 'retained'
when cm2.cur_lego_year < cm1.cur_lego_year and ams.eff_member_detail_id is null then 'other'
else 'exception' end as life_stage_fy,

case
when cm2.cur_lego_year = cm1.cur_lego_year and cm2.cur_lego_month = cm1.cur_lego_month then 'new'
when cm2.cur_lego_year = cm1.cur_lego_year and cm2.cur_lego_month < cm1.cur_lego_month and ams.eff_member_detail_id is not null then 'retained'
when cm2.cur_lego_year < cm1.cur_lego_year and ams.eff_member_detail_id is not null then 'retained'
when cm2.cur_lego_year = cm1.cur_lego_year and cm2.cur_lego_month < cm1.cur_lego_month and ams.eff_member_detail_id is null then 'other'
when cm2.cur_lego_year < cm1.cur_lego_year and ams.eff_member_detail_id is null then 'other'
else 'exception' end as life_stage_ytd,


case
when tr.eff_shopid = 'dy-brand-store' and date(pi.douyin_brand_launch_date) >= '2023-12-25' and date(pi.douyin_brand_launch_date) < '2024-02-21' then 'y'
when tr.eff_shopid = 'dy-family-store' and date(pi.douyin_family_launch_date) >= '2023-12-25' and date(pi.douyin_family_launch_date) < '2024-02-21' then 'y'
else 'n' end as novelty_flag_2024_ytd


from tutorial.dy_trans_sku_ext as tr
left join edw.d_dl_product_info_latest as pi
on tr.lego_sku_id = pi.lego_sku_id
left join tutorial.lego_calendar_mapping_roy_v2 as cm1
on date(tr.date_id) = date(cm1.cur_date)
left join tutorial.lego_calendar_mapping_roy_v2 as cm2
on date(tr.belong_date_ext) = date(cm2.cur_date)
left join annual_member_shopper as ams
on tr.eff_member_detail_id = ams.eff_member_detail_id
and cm1.cur_lego_year - ams.trans_lego_year = 1
left join member_parent_order_rank as mpor
on tr.parent_order_id = mpor.parent_order_id
left join tutorial.adult_sku_list_roy_v2 as adsku
on cast(tr.lego_sku_id as varchar) = cast(adsku.lego_sku_id as varchar)
left join tutorial.focus_sku_list_roy as fsku
on cast(tr.lego_sku_id as varchar) = cast(fsku.lego_sku_id as varchar)
and date(fsku.start_date) <= date(tr.date_id)
and date(fsku.end_date) >= date(tr.date_id)
where 1 = 1
and tr.date_id >= '2024-01-01'
and tr.date_id < '2024-02-21' -- 2024 Jan lego month end date
and tr.eff_member_detail_id is not null
and tr.mbr_purchase_flag_ext = 1 -- only take member order