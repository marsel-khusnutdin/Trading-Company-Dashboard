-- Orders for import into Tableau

    SELECT 
        l.user_uid,
  	 	u.country,
        ord.id as order_id,
        ord.order_open_date as order_open_datetime,
        ord.order_close_date as order_close_datetime,
        ord.volume_usd as volume
    FROM db_orderstat.tb_orders ord
    INNER JOIN db_default.tb_logins l 
        ON ord.login = l.login
    INNER JOIN db_default.tb_users u
    	ON l.user_uid = u.uid
    WHERE l.account_type = 'real';
