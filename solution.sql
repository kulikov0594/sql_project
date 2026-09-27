create schema if not exists raw_data;

create table if not exists raw_data.sales ();


alter table raw_data.sales
    add column id text,
    add column auto text,
    add column gasoline_consumption text,
    add column price text,
    add column date text,
    add column person_name text,
    add column phone text,
    add column discount text,
    add column brand_origin text;

--------------------

create schema if not exists car_shop; 

----------------------


select 
	phone
	,count(distinct person_name)
from raw_data.sales s 
group by 1 
having count(distinct person_name) > 1


select 
	distinct s.phone 
from raw_data.sales s 

drop table car_shop.clients;

create table car_shop.clients (
	id serial primary key,		/* инкремент */
	name text not null,		/* разная длина, используем текст */
	phone text not null unique 		/* разная длина и спецсимволы, также текст */
)



create table car_shop.brands (
    id serial primary key,       /* инкремент марки */
    name text not null unique,   /* название марки обязательное и не должно повторяться*/
    origin text                  /* страна происхождения, null допустим для порше*/
);



create table car_shop.models (
    id serial primary key,                   /* инкремент модели */
    brand_id integer not null references car_shop.brands(id),      /* ссылка на марку автомобиля */
    name text not null,                      /* название модели обязательное */
    gasoline_consumption numeric(3,1),       /* расход до десятых, null для электромобилей */
    unique (brand_id, name)                  /* модель не должна повторяться внутри одной марки */
);



create table car_shop.colors (
    id serial primary key,       /* инкремент цвета */
    name text not null unique    /* название цвета обязательное и не должно повторяться */
);



create table car_shop.cars (
    id serial primary key,                               /* инкремент автомобиля */
    model_id integer not null references car_shop.models(id),                  /* ссылка на модель автомобиля */
    color_id integer not null references car_shop.colors(id),                  /* ссылка на цвет автомобиля */
    unique (model_id, color_id)                          /* одинаковое сочетание модели и цвета не повторяется */
);



create table car_shop.sales (
    id serial primary key,                           /* инкремент для продажи */
    source_id integer not null unique,               /* id продажи из исходного csv*/
    car_id integer not null references car_shop.cars(id),        /* ссылка на автомобиль определённой модели и цвета */
    client_id integer not null references car_shop.clients(id),    /* ссылка на клиента */
    price numeric(9,2) not null,                     /* цена хранится с точностью до сотых */
    date date not null,                              /* дата продажи */
    discount smallint not null,                      /* скидка в целых процентах */
    check (price > 0),                               /* цена должна быть положительной */
    check (discount between 0 and 100)               /* скидка должна быть от 0 до 100 процентов */
);





---insert
insert into car_shop.clients (name, phone)
select distinct
    person_name,
    phone
from raw_data.sales
order by phone
on conflict (phone) do nothing;




insert into car_shop.brands (name, origin)
select distinct
    split_part(auto, ' ', 1) as brand_name,
    nullif(brand_origin, 'null') as brand_origin
from raw_data.sales
order by brand_name
on conflict (name) do nothing;



insert
	into
	car_shop.models (
		brand_id,
		name,
		gasoline_consumption
	)
select
	distinct
    b.id,
	replace(
        split_part(r.auto, ',', 1),
        b.name || ' ',
        ''
    ),
	nullif(r.gasoline_consumption, 'null')::numeric(3, 1)
from
	raw_data.sales as r
join car_shop.brands as b
    on
	b.name = split_part(r.auto, ' ', 1);


insert into car_shop.colors (name)
select distinct
    split_part(auto, ', ', 2)
from raw_data.sales;






insert into car_shop.cars (
    model_id,
    color_id
)
select distinct
    m.id,
    c.id
from raw_data.sales as r
join car_shop.brands as b
    on b.name = split_part(r.auto, ' ', 1)
join car_shop.models as m
    on m.brand_id = b.id
    and b.name || ' ' || m.name = split_part(r.auto, ', ', 1)
join car_shop.colors as c
    on c.name = split_part(r.auto, ', ', 2);




insert into car_shop.sales (
    source_id,
    car_id,
    client_id,
    price,
    date,
    discount
)
select
    r.id::integer,
    car.id,
    cl.id,
    r.price::numeric(9,2),
    r.date::date,
    r.discount::smallint
from raw_data.sales as r
join car_shop.clients as cl on cl.phone = r.phone
join car_shop.brands as b on b.name = split_part(r.auto, ' ', 1)
join car_shop.models as m on m.brand_id = b.id and b.name || ' ' || m.name = split_part(r.auto, ', ', 1)
join car_shop.colors as c on c.name = split_part(r.auto, ', ', 2)
join car_shop.cars as car on car.model_id = m.id and car.color_id = c.id;




-----------
---- Задание 1 
select 
	round(count(*) filter (where m.gasoline_consumption is null)::numeric / count(*) * 100 , 2) as nulls_percentage_gasoline_consumption
from car_shop.models m


------------
--Задание 2
select 
b."name" as brand_name
,extract (year from s.date) as year
,round(avg(s.price),2) as price_avg
from car_shop.cars c 
join car_shop.models m on c.model_id  = m.id
join car_shop.brands b on m.brand_id  = b.id
join car_shop.sales s on s.car_id = c.id
group by 1,2
order by 1,2;

----------
--Задание 3
select 
extract (month from s.date) as month
,extract (year from s.date) as year
,round(avg(s.price),2) as price_avg
from car_shop.sales s 
where 
	1=1 
	and s.date >='2022-01-01'
	and s.date <'2023-01-01'
group by 1,2
order by 1,2;



----------
---Задание 4
select
    cl.name as person
    ,string_agg(b.name || ' ' || m.name, ', ') as cars
from car_shop.sales as s
join car_shop.clients as cl on cl.id = s.client_id
join car_shop.cars as c on c.id = s.car_id
join car_shop.models as m on m.id = c.model_id
join car_shop.brands as b on b.id = m.brand_id
group by cl.id, cl.name
order by cl.name;



---------
--Задание 5 
select
    b.origin as brand_origin,
    round(max(s.price + s.price * s.discount / (100 - s.discount)), 2) as price_max,
    round(min(s.price + s.price * s.discount / (100 - s.discount)), 2) as price_min
from car_shop.cars as c
join car_shop.models as m on c.model_id = m.id
join car_shop.brands as b on m.brand_id = b.id
join car_shop.sales as s on s.car_id = c.id
where b.origin is not null
group by 1;

-------
---Задание 6 
select 
count(*) as persons_from_usa_count
from car_shop.clients c 
where c.phone ilike '+1%'






























