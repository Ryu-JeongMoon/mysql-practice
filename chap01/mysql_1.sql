create table employees_comp8k
(
    emp_no     int             not null,
    birth_date date            not null,
    first_name varchar(14)     not null,
    last_name  varchar(16)     not null,
    gender     enum ('M', 'F') not null,
    hire_date  date            not null,
    primary key (emp_no),
    key ix_firstname (first_name),
    key ix_hiredate (hire_date)
) row_format = compressed
  key_block_size = 8;

drop table employees_comp8k;

insert into employees_comp8k
select *
from employees;

select table_name,
       index_name,
       compress_ops,
       compress_ops_ok,
       (compress_ops - compress_ops_ok) / compress_ops * 100 as compression_failure_pct
from information_schema.INNODB_CMP_PER_INDEX;

select *
from employees_comp8k;

select *
from employees_comp4k;

set global innodb_cmp_per_index_enabled = on;

#################################################################

select (sum(sum_timer_read) / sum(count_read)) / 1000000000   as avg_read_latency_ms,
       (sum(sum_timer_write) / sum(count_write)) / 1000000000 as avg_write_latency_ms
from performance_schema.file_summary_by_instance
where FILE_NAME like '%DB_NAME/TABLE_NAME';

show plugins;

select table_schema, table_name, create_options
from information_schema.tables
where table_name = 'tab_encrypted';

#################################################################
# 8 - index
explain
select *
from employees
where first_name between 'Ebbe' and 'Gad';

explain
select *
from employees
where first_name in ('Ebbe', 'Gad');

show status like 'Handler_%';
show tables;
show index from employees;
set optimizer_switch = 'skip_scan=on';

explain
select dept_no, min(emp_no)
from dept_emp
where dept_no between 'd002' and 'd004'
group by dept_no;

explain
select gender, birth_date
from employees
where birth_date >= '1965-02-01';

explain
select *
from employees
where birth_date >= '1965-02-01';

explain
select *
from employees
where gender = 'M'
  and birth_date >= '1965-02-01';

explain
select *
from employees
where first_name >= 'Anneke'
order by first_name asc
limit 4;

explain
select *
from employees
order by first_name desc
limit 5;

select *
from employees
order by first_name asc
limit 10;

select *
from employees
order by first_name desc
limit 10;

create table t1
(
    tid              int not null auto_increment,
    table_name       varchar(64),
    column_name      varchar(64),
    ordinal_position int,
    primary key (tid)
) engine = innoDB;


#################################################################
# 9 - optimizer
# 단순 레코드 건수만 병렬 처리 가능하다 CPU 코어 이상으로 설정 시, context switching 비용 때문에 성능 하락할 수 있음
# 프로젝트에 적용 가능? -> 추후 더 알아볼 것
set session innodb_parallel_read_threads = 1;
set session innodb_parallel_read_threads = 2;
set session innodb_parallel_read_threads = 4;
set session innodb_parallel_read_threads = 8;

select count(*)
from salaries;

select *
from salaries
order by to_date
limit 999999999, 1;

# 9.2.5 DISTINCT 처리
explain
select distinct emp_no
from salaries;

explain
select emp_no
from salaries
group by emp_no;

select distinct first_name, last_name
from employees;
# (first_name, last_name) 둘 다 유니크한 값 가져옴

select distinct(first_name), last_name
from employees;
# distinct 함수가 아니기 때문에 실행할 때 괄호 없애버린다
# select 절에 사용된 distinct 는 모든 컬럼에 영향 미친다

explain
select count(distinct s.salary)
from employees e,
     salaries s
where e.emp_no = s.emp_no
  and e.emp_no between 100001 and 100100;
# 집합 함수와 함께 사용되는 distinct 는 다르다

explain
select count(distinct s.salary), count(distinct e.last_name)
from employees e,
     salaries s
where e.emp_no = s.emp_no
  and e.emp_no between 100001 and 100100;

# MySQL 8.0.18 이후 부터 Using join buffer (block nested loop) -> (hash join)으로 바뀜
explain
select *
from dept_emp de,
     employees e
where de.from_date > '1995-01-01'
  and e.emp_no < 109004;

# 9.3.1.3 index_condition_pushdown
# 이걸 안 쓰던 이유는 실행 계획은 MySQL 엔진이 짜고 수행하고, 읽기 작업은 DB Engine (InnoDB Engine)이 수행했기 때문이고 MySQL 5.6 이후 부터 개선되었다
# last_name 을 읽을 때 이미 first_name 도 읽었으니 이걸 활용하면 불필요한 읽기 작업을 줄일 수 있다
alter table employees
    add index ix_lastname_firstname (last_name, first_name);

set optimizer_switch = 'index_condition_pushdown=off';
set optimizer_switch = 'index_condition_pushdown=on';

show variables like 'optimizer_switch';

explain
select *
from employees
where last_name = 'Acton'
  and first_name like '%sal';

# 9.3.1.4 use_index_extensions
# explain 에서 key 속성은 어느 칼럼을 사용했는지 이름을 보여주고, key_len 속성은 바이트 수로 보여준다
explain
select count(*)
from dept_emp
where from_date = '1987-07-25'
  and dept_no = 'd001';

explain
select count(*)
from dept_emp
where from_date = '1987-07-25';

# Extra에 Filesort가 없다는 것은 정렬 작업 없이 인덱스 순서대로 읽어왔음을 의미
explain
select *
from dept_emp
where from_date = '1987-07-25'
order by dept_no;

# 9.3.1.5 index_merge
# 일반적으로 optimizer는 테이블 별로 하나의 index만 사용해서 읽어오고 나머지 조건들은 체크하는 식으로 수행되는데 -> 이게 효율적이기 때문
# where 조건에 여러 인덱스가 사용되고 만족하는 레코드 건수가 많다면 index_merge 실행 계획을 선택한다

# index_merge_intersection
# 각각의 인덱스를 사용하고 교집합만 반환했다!
# Using intersect(ix_firstname,PRIMARY); Using where
explain
select *
from employees
where first_name = 'Georgi'
  and emp_no between 10000 and 20000;

select count(*)
from employees
where first_name = 'Georgi';

select count(*)
from employees
where emp_no between 10000 and 20000;

select count(*)
from employees
where first_name = 'Georgi'
  and emp_no between 10000 and 20000;

set global optimizer_switch = 'index_merge_intersection=off';
set session optimizer_switch = 'index_merge_intersection=off';

explain
select /*+ set_var(optimizer_switch='index_merge_intersection=off') */ *
from employees
where first_name = 'Georgi'
  and emp_no between 10000 and 20000;

# index_merge_union
# Using union(ix_firstname,ix_hiredate); Using where, union이라는 알고리즘을 사용해 결과를 가져온 것이다
# union은 priority queue를 이용해 중복을 제거하고 두 결과 집합을 병합해 가져온다
# SQL에서 and 와 or 는 차이가 크다 or를 조심히 쓰자!
# and - 조건 중 하나라도 index 사용 가능하다면 그걸로 처리 or - 조건 중 하나라도 index 사용하지 못 하면 full scan 때려버린다
explain
select *
from employees
where first_name = 'Matt'
   or hire_date = '1987-03-31';

# index_merge_sort_union
explain
select *
from employees
where first_name = 'Matt'
   or hire_date between '1987-03-01' and '1987-03-31';

# 얘는 emp_no 정렬된 상태
select *
from employees
where first_name = 'Matt';

# 얘는 emp_no 정렬 안된 상태
select *
from employees
where hire_date between '1987-03-01' and '1987-03-31';

# 9.3.1.9 semijoin
# query 실제 수행하지는 않고 다른 테이블에서 조건에 일치하는 레코드가 있는지 체크할 때만 사용하기 위한 형태의 query

explain
select /*+ set_var(optimizer_switch='semijoin=off') */ *
from employees e
where e.emp_no in (select de.emp_no from dept_emp de where de.from_date = '1995-01-01');

explain
select *
from employees e
where e.emp_no in (select de.emp_no from dept_emp de where de.from_date = '1995-01-01');

# Table Pull-out
# 최대한 서브쿼리를 조인으로 풀어서 사용해라 라는 MySQL의 튜닝 가이드를 그대로 실행한 기법
explain
select *
from employees e
where e.emp_no in (select de.emp_no from dept_emp de where de.dept_no = 'd009');

# explain 실행되고 어떤 쿼리가 나갔는지 확인하는 방법, output 에 결과 나옴
show warnings;

# 9.3.1.11 firstmatch
# in -> exist 로 튜닝
# id column 같다면 서브쿼리 실행 X, Join 처리됐다는 뜻
explain
select *
from employees e
where e.first_name = 'Matt'
  and e.emp_no in (
    select t.emp_no from titles t where t.from_date between '1995-01-01' and '1995-01-30'
);

# 9.3.1.12 loosescan
explain
select *
from departments d
where d.dept_no in (
    select de.dept_no
    from dept_emp de
);

# 9.3.1.13 Materialization
# 구체화를 통해 쿼리를 최적화 -> 내부 임시 테이블을 생성
explain
select *
from employees e
where e.emp_no in (select de.emp_no from dept_emp de where de.from_date = '1995-01-01');

set optimizer_switch = 'use_invisible_indexes=on';
set optimizer_switch = 'use_invisible_indexes=default';


# 10.1 statistic information
show tables like '%_stats';

alter table employees.employees
    stats_persistent = 1;

analyze table employees.employees
    update histogram on gender, hire_date;

# 단순 통계 정보 이용 시 11%로 예측됨
explain
select *
from employees e
where e.first_name = 'Zita'
  and e.birth_date between '1950-01-01' and '1960-01-01';

# histogram 정보 수집
analyze table employees update histogram on first_name, birth_date;

analyze table employees drop histogram on first_name, birth_date;

# 정보 수집 후 60.86 %로 예측됨
explain
select *
from employees e
where e.first_name = 'Zita'
  and e.birth_date between '1950-01-01' and '1960-01-01';

# 실제 비율 63.84%
select sum(case when birth_date between '1950-01-01' and '1960-01-01' then 1 else 0 end) / count(*) as ratio
from employees
where first_name = 'Zita';

explain analyze
select * from employees where first_name = 'Matt';


