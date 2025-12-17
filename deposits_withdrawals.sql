-- Transaction for import into Tableau
    SELECT 
        l.user_uid,
  	 	u.country,
        op.id as transaction_id,
        op.operation_date,
        op.operation_type,
        op.amount
    FROM db_transaction.tb_operations op
    INNER JOIN db_default.tb_logins l 
        ON op.login = l.login
    INNER JOIN db_default.tb_users u
    	ON l.user_uid = u.uid
    WHERE l.account_type = 'real';
