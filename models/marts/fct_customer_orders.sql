with

-- Import CTEs
base_customers as (

    select * from {{ ref('stg_jaffle_shop_customers') }}

),

base_orders as (

     select * from {{ ref('stg_jaffle_shop_orders') }}

),

base_payments as (

     select * from {{ ref('stg_stripe_payments') }}

),

-- Logical CTEs

--staging
customers as (

    select 
        id as customer_id,
        last_name as surname,
        first_name as givenname,
        first_name || ' ' || last_name as full_name

    from base_customers

),

orders as (

      select 
      id as order_id,
      user_id as customer_id,
      order_date,
      status as order_status,

        row_number() over (
            partition by user_id 
            order by order_date, id
        ) as user_order_seq,
        *

      from base_orders

),

payments as (
select 
 payment_id,
 orderid as order_id,
 status payment_status,
 round(amount/100.0) as payment_amount
 from base_payments
),



--marts
customer_order_history as (

    select 

        customers.customer_id,
        customers.full_name,
        customers.surname,
        customers.givenname,

        min(order_date) as first_order_date,

        min(case 
            when orders.order_status not in ('returned','return_pending') 
            then order_date 
        end) as first_non_returned_order_date,

        max(case 
            when orders.order_status not in ('returned','return_pending') 
            then order_date 
        end) as most_recent_non_returned_order_date,

        coalesce(max(user_order_seq),0) as order_count,

        coalesce(count(case 
            when orders.status != 'returned' 
            then 1 end),
            0
        ) as non_returned_order_count,

        sum(case 
            when orders.status not in ('returned','return_pending') 
            then payments.payment_amount 
            else 0 
        end) as total_lifetime_value,

        sum(case 
            when orders.status not in ('returned','return_pending') 
            then payments.payment_amount
            else 0 
        end)
        / nullif(count(case 
            when orders.status not in ('returned','return_pending') 
            then 1 end),
            0
        ) as avg_non_returned_order_value,

        array_agg(distinct orders.order_id) as order_ids

    from orders

    join customers
    on orders.user_id = customers.customer_id

    left outer join payments 
    on orders.id = payments.order_id

    where orders.status not in ('pending') and payments.payment_status != 'fail'

    group by customers.customer_id, customers.full_name, customers.surname, customers.givenname

),

-- Final CTEs 
final as (

    select 

        orders.order_id,
        orders.customer_id,
        customers.surname,
        customers.givenname,
        first_order_date,
        order_count,
        total_lifetime_value,
        payment_amount as order_value_dollars,
        orders.order_status,
        payments payment_status

    from orders

    join customers
    on orders.user_id = customers.customer_id

    join customer_order_history
    on orders.user_id = customer_order_history.customer_id

    left outer join payments
    on orders.id = payments.order_id

    where payments.status != 'fail'

)

-- Simple Select Statement
select * from final