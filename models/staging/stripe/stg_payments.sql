with payments as (
     select ID, ORDERID as order_id, PAYMENTMETHOD, STATUS, AMOUNT, CREATED, _BATCHED_AT
      from  {{ source('stripe', 'payment') }}
)
select * from payments