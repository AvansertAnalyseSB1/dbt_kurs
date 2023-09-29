with 
 source as 
 (
    {{ source('stripe', 'payment') }}
 ),

payments as (
select 
 payment_id,
 orderid as order_id,
 status payment_status,
 round(amount/100.0) as payment_amount
 from source
)

select * from payments