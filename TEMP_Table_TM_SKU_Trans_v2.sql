drop table if exists tutorial.tm_sku_trans_roy_v2; -- for the 1st time of table creation
create table tutorial.tm_sku_trans_roy_v2 as -- for the 1st time of table creation

-- 2022全年 = 2022-01-03 to 2023-01-01
-- 2023全年 = 2023-01-02 to 2023-12-31
-- 2023 Jan YTD = 2023-01-02 to 2023-01-29
-- 2024 Jan YTD = 2024-01-01 to 2024-01-28

with
annual_member_shopper as
    (
        select
        tr.kyid,
        cm1.cur_lego_year as trans_lego_year
        from edw.f_oms_order_dtl_upd as tr
        left join tutorial.lego_calendar_mapping_roy_v2 as cm1
        on date(tr.payment_confirm_time) = date(cm1.cur_date)
        where 1 = 1
        and is_delivered = 'Y'
        and is_gwp = 'N'
        and lego_sku_gmv_price>= 59
        and lego_sku_rrp_price > 0
        and platformid = 'taobao'
        and tr.is_member = 1
        and tr.kyid is not null
        and date(payment_confirm_time) < '2024-02-21' -- start date
        group by
        tr.kyid,
        cm1.cur_lego_year
    ),

member_parent_order_rank as
    (
        select
        a.*,
        row_number() over (partition by a.kyid order by a.porder_time asc) as rnk_in_life
        from
            (
                select
                tr.kyid,
                tr.parent_order_id,
                min(payment_confirm_time) as porder_time
                from edw.f_oms_order_dtl_upd as tr
                where 1 = 1
                and is_delivered = 'Y'
                and is_gwp = 'N'
                and lego_sku_gmv_price>= 59
                and lego_sku_rrp_price > 0
                and platformid = 'taobao'
                and tr.is_member = 1
                and tr.kyid is not null
                and date(payment_confirm_time) < '2024-02-21' -- start date
                group by
                tr.kyid,
                tr.parent_order_id
            ) as a
    ),

member_with_kid as
    (
        select
        distinct a.member_detail_id
        from
            (
                select
                cast(member_detail_id as varchar) as member_detail_id
                from edw.d_dl_crm_birthday_history kids_birthday 
                where 1 = 1
                and person_type = 2
                union all
                select
                cast(id as varchar) as member_detail_id
                from edw.f_crm_member_detail
                where 1 = 1
                and join_time < current_date
                and has_kid = 1    
            ) as a
    ),

scapler_fact as
    (
        select
        distinct kyid -- total = 3,831; member shopper in time window = 2,991
        from edw.f_oms_order_dtl_upd
        where 1 = 1
        and platform_order_id in
            ( 
                select 
                replace(tmall_order_id, ',', '')
                from tutorial.mz_tmall_scalper_order_20231210
            )
    )

--------------------------------------------

select
tr.kyid,
tr.member_detail_id,
date(tr.payment_confirm_time) as payment_confirm_date,
cm1.cur_lego_year as trans_lego_year,
cm1.cur_lego_month as trans_lego_month,
tr.payment_confirm_time,
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

dc.city as delivery_city,
case
when ct.city_tier in ('Tier 1', 'Tier 2', 'Tier 3') then ct.city_tier
else 'Tier 4+' end as delivery_city_tier,
coalesce(mct.city_type, '4_others') as city_type,

case when cm1.cur_lego_year in (2022, 2023) then concat(cast(cm1.cur_lego_year as varchar), '_fy') else 'exception' end as trans_period_fy,
case when (date(tr.payment_confirm_time) >= '2023-01-02' and date(tr.payment_confirm_time) < '2023-02-22')
    or (date(tr.payment_confirm_time) >= '2024-01-01' and date(tr.payment_confirm_time) < '2024-02-21')
    then concat(cast(cm1.cur_lego_year as varchar), '_ytd') else 'exception' end trans_period_ytd,

tm_reg.tm_reg_time,
cm2.cur_lego_year as reg_lego_year,
cm2.cur_lego_month as reg_lego_month,

case -- cm1 refers to trans lego year, cm2 refers to TM registration year, ams.kyid refers to memeber shoppers from the previous year
when cm2.cur_lego_year = cm1.cur_lego_year then 'new'
when cm2.cur_lego_year < cm1.cur_lego_year and ams.kyid is not null then 'retained'
when cm2.cur_lego_year < cm1.cur_lego_year and ams.kyid is null then 'other'
else 'exception' end as life_stage_fy,

case
when cm2.cur_lego_year = cm1.cur_lego_year and cm2.cur_lego_month = cm1.cur_lego_month then 'new'
when cm2.cur_lego_year = cm1.cur_lego_year and cm2.cur_lego_month < cm1.cur_lego_month and ams.kyid is not null then 'retained'
when cm2.cur_lego_year < cm1.cur_lego_year and ams.kyid is not null then 'retained'
when cm2.cur_lego_year = cm1.cur_lego_year and cm2.cur_lego_month < cm1.cur_lego_month and ams.kyid is null then 'other'
when cm2.cur_lego_year < cm1.cur_lego_year and ams.kyid is null then 'other'
else 'exception' end as life_stage_ytd,

case
when mbr.gender = 1 then 'm'
when mbr.gender = 2 then 'f'
when mbr.gender = 0 then 'u'
else 'exception' end as gender,

date(mbr.birthday) as birthday,
(date('2024-01-28') - date(mbr.birthday))/365 as age,

case when mwk.member_detail_id is not null then 'y' else 'n' end as has_kid,

case when sf.kyid is not null then 'y' else 'n' end as scalper_flag,

date(pi.cn_tm_launch_date) as launch_date,

case when cm1.cur_lego_year = cm3.cur_lego_year then 'y' else 'n' end as novelty_flag_fy,
case when date(pi.cn_tm_launch_date) >= '2023-12-25' and date(pi.cn_tm_launch_date) < '2024-02-21' then 'y' else 'n' end as novelty_flag_2024_ytd


from edw.f_oms_order_dtl_upd as tr
left join edw.d_dl_product_info_latest as pi
on tr.lego_sku_id = pi.lego_sku_id
left join
    (
        select
        platform_id_value as kyid,
        min(first_bind_time) as tm_reg_time
        from edw.d_ec_b2c_member_shopper_detail_latest
        where 1 = 1
        and platform_id_type = 'kyid' -- platform_id_type: opendi / kyid
        and platformid = 'taobao' -- platformid: douyin / taobao
        and first_bind_time < '2024-02-21'
        group by
        platform_id_value
    ) as tm_reg
on tr.kyid = tm_reg.kyid
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
left join tutorial.mz_city_tier_v2 as ct
on dc.city = ct.city_chn
left join tutorial.lego_calendar_mapping_roy_v2 as cm1
on date(tr.payment_confirm_time) = date(cm1.cur_date)
left join tutorial.lego_calendar_mapping_roy_v2 as cm2
on date(tm_reg.tm_reg_time) = date(cm2.cur_date)
left join annual_member_shopper as ams
on tr.kyid = ams.kyid
and cm1.cur_lego_year - ams.trans_lego_year = 1
left join member_parent_order_rank as mpor
on tr.parent_order_id = mpor.parent_order_id
left join tutorial.adult_sku_list_roy_v2 as adsku
on cast(tr.lego_sku_id as varchar) = cast(adsku.lego_sku_id as varchar)
left join tutorial.focus_sku_list_roy as fsku
on cast(tr.lego_sku_id as varchar) = cast(fsku.lego_sku_id as varchar)
and date(fsku.start_date) <= date(tr.payment_confirm_time)
and date(fsku.end_date) >= date(tr.payment_confirm_time)
left join edw.f_crm_member_detail as mbr
on cast(tr.member_detail_id as varchar) = cast(mbr.id as varchar)
left join member_with_kid as mwk
on cast(tr.member_detail_id as varchar) = cast(mwk.member_detail_id as varchar)
left join scapler_fact as sf
on tr.kyid = sf.kyid
left join tutorial.lego_calendar_mapping_roy_v2 as cm3
on date(pi.cn_tm_launch_date) = date(cm3.cur_date)
left join tutorial.mkt_city_type_roy_v1 as mct
on dc.city = mct.city_chn
where 1 = 1
and tr.is_delivered = 'Y'
and tr.is_gwp_via_gmv = 'N'
and tr.lego_sku_gmv_price >= 59
and tr.lego_sku_rrp_price > 0
and tr.platformid = 'taobao'
and date(tr.payment_confirm_time) < '2024-02-21' -- 2024 Jan lego month end date
and tr.kyid is not null
and tr.is_member = 1 -- only take member order