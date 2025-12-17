--query to import into Tableau
with cte_user_first_deposit_date as (

select l.user_uid,
	   min(op.operation_date) as first_deposit_date
from db_transaction.tb_operations op
inner join db_default.tb_logins l
	on op.login = l.login
where l.account_type = 'real'
  and op.operation_type = 'deposit'
group by l.user_uid
  
 ),
 
cte_user_first_trade_date as (

select l.user_uid,
	   min(date(ord.order_open_date)) as first_trade_date
from db_orderstat.tb_orders ord
inner join db_default.tb_logins l
	on ord.login = l.login
where l.account_type = 'real'
group by l.user_uid
 
), 

cte_final as (

select u.uid,
	   u.country,
	   u.registration_date,
       fdd.first_deposit_date,
       ftd.first_trade_date,       
       fdd.first_deposit_date - u.registration_date as registration_to_first_deposit_days,      
       ftd.first_trade_date - fdd.first_deposit_date as first_deposit_to_first_trade_days
from db_default.tb_users u
left join cte_user_first_deposit_date fdd
	on u.uid = fdd.user_uid
left join cte_user_first_trade_date ftd
	on u.uid = ftd.user_uid)
    
 select * from cte_final;
