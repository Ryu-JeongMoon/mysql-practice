# 쿼리 작성 및 최적화

# 11.1 쿼리 작성과 연관된 시스템 변수
# sql_mode 설정을 통해 쿼리 결과에 영향을 미치는 시스템 설정 가능

# 11.1.2 영문 대소문자 구분
# 윈도우에서는 구분 안 하는데 유닉스 계열에서는 구분함, 이종 간 호환 문제가 있을 수 있으므로
# MySQL lower_case_table_names 시스템 설정을 하던지 팀의 규약을 통해 해결해야 함
# 가능하면 방식 통일해서 사용하는게 젤 깔끔

# 11.1.3 예약어
# 여러 예약어가 있고 다 알 필요 없으니 테이블 생성해보고 안 되면
# `` 백틱 써서 만들던지 이렇게 하믄 추후 사용시에도 귀찮으니 이름 살짝 바꿔서 저장할 것 ex. ORDER -> ORDERS

# 11.3.1 리터럴 표기법 문자열
# MySQL 만의 방식이 있지만 ANSI 로 통일해서 사용할 것
SELECT @@GLOBAL.sql_mode;
set global sql_mode = 'ansi';

# 11.3.1.2 숫자
# MySQL 에서는 숫자가 문자에 대해 우선권을 가지므로 자동 형변환 시 문자 타입이 숫자로 변환된다
# where 절에 문자타입 = 숫자타입으로 비교 시
# 문자가 숫자로 변환된 후 비교되기 땜시 인덱스가 있어도 타입 변환되었기 때문에 타지 않는다
# 또한 문자타입에서 숫자로 변환될 수 없는 문자가 포함된 경우 쿼리 터질 수도 있당

# 13.3.1.3 날짜
# MySQL 똑똑이는 date 타입 자동 변환이 일어나서 str_to_date 안 써도 됨
select *
from dept_emp
where from_date = '2011-04-29';

select *
from dept_emp
where from_date = str_to_date('2011-04-29', '%Y-%m-%d');

# 13.3.1.4 불리언
# BOOL, BOOLEAN 있긴 한데 TINYINT 의 동의어일 뿐
# 0, 1 아니어도 들어가긴 하는데 true, false 로 조회 시 안 뜸, 명확히 0 - false, 1 - true 매핑되기 때문
# boolean 쓰고 싶어 죽겠으면 enum 타입 고려할 것
create table tb_boolean
(
    bool_value BOOLEAN
);

insert into tb_boolean
values (false),
       (true),
       (2),
       (3),
       (4),
       (5);

select *
from tb_boolean
where bool_value = FALSE;

select *
from tb_boolean
where bool_value = TRUE;

select *
from tb_boolean
where bool_value in (true, false);

# 11.3.2 MySQL 연산자
# null-safe 비교 연산자, null 을 하나의 값으로 인식해서 비교하는 방법, 무슨 의미가 있을까?
select 1 = 1, null = null, 1 = null;
select 1 <=> 1, null <=> null, 1 <=> null;
select ! 1;
select ! False;
select not 1;

# Like 연산자
select 'abc' like 'a%';

# 와일드카드 문자가 검색어 뒤에 있으면 index range scan 가능,
explain
select count(*)
from employees
where first_name like 'Christ%';

# 검색어 앞에 있으면 불가능, index full scan
explain
select count(*)
from employees
where first_name like '%rist';

# 11.3.2.8 Between
# 얘는 범위를 읽어야 해서 많은 레코드를 읽어야 한다
# in 은 = 동등 비교를 여러번 하는 것을 묶은 것이므로 (dept_no, emp_no) 처럼 묶인 키가 있다면
# dept_no in (blah blah) and emp_no = blah 형식으로 하는게 훨씬 효율적
explain
select *
from dept_emp use index (`PRIMARY`)
where dept_no between 'd003' and 'd005'
  and emp_no = 10001;

explain
select *
from dept_emp use index (`PRIMARY`)
where dept_no in ('d003', 'd004', 'd005')
  and emp_no = 10001;

explain
select *
from departments d
         inner join dept_emp de use index (`PRIMARY`) on d.dept_no = de.dept_no and de.emp_no = 10001
where d.dept_no between 'd003' and 'd005';

# 11.3.3 MySQL 내장 함수
# now 는 쿼리 진입 시점에 시간으로 고정
# sysdate 는 사용되는 구문 진입 시점 시간으로 설정 (첫번째놈이랑 두번째놈 시간 다름)
select ifnull(null, 1);
select isnull(1 / 0);
select now();
select sysdate(), sleep(1), sysdate();

select date_format(now(), '%Y-%m-%d') as current_dt;

# 11.4.2.1 인덱스 사용 규칙
explain
select *
from salaries
where salary * 10 > 150000;

explain
select *
from salaries
where salary > 155000;

# 11.4.2.3 group by 절 인덱스 사용
# 다중 컬럼 사용 시 순서 일치해야 하고 뒤쪽 컬럼은 group by 에 명시하지 않아도 사용할 수 있고 앞쪽 컬럼은 명시되지 않으면 사용할 수 없다
# group by 절에 index 가 아닌 녀석이 있는 경우에는 전체가 index 타지 않는다
# where 절에서 인덱스 걸려있는 col1, col2 가 사용될 때 group by 절에서 col3 만 이용해도 index mapping 가능하다

# 11.4.2.4 order by 절 인덱스 사용
# group by 절과 처리 방법이 비슷하며 조건이 하나 더 추가되는데 모든 컬럼이 오름차순 & 내림차순 일치되어 있는 경우에만 사용 가능
# ex) col1, col2 desc, col3 -> col2 가 내림차순으로 되어있어 일치되지 않으므로 사용 불가

# 11.4.2.5 where & order by / group by 절 인덱스 사용
# 1. where & order by 절 동시에 같은 인덱스 사용
# 2. where 절에서 인덱스 사용 후 order by 절은 using Filesort 로 인덱스 타지 않는 정렬 수행 -> where 로 걸러낸 컬럼이 적을 때 유용
# 3. order by 절에서만 인덱스 사용 -> 대량의 데이터 조회 시 사용 ??
# MySQL 8.0 버전부터 선행되는 인덱스가 없어도 후행 인덱스를 사용할 수 있게 하는 index skip scan 최적화 사용 가능!
# where col1 = blah order by col2, col3 일 때는 인덱스 타고
# where col1 > blah order by col2, col3 일 때는 인덱스 못 탐 (동등 비교 / 범위 비교로 인한 차이)

# 11.4.2.6 group by / order by 인덱스 사용
# 얘네는 무조건 일치해야 함, 한쪽이라도 인덱스를 타지 못하는 경우 둘다 인덱스 안 탐

# 11.4.2.7 where & order by / group by
# 아래 세가지 조건 모두 만족해야 전부 인덱스 타고, 1만 만족하는 경우 where 절 index, 2 & 3만 만족하는 경우 group by / order by 인덱스 탐
# 1. where 절 인덱스 사용하는가?
# 2. group by 절 인덱스 사용하는가?
# 3. group by / order by 절 인덱스 사용하는가?

# 11.4.3 where 절 비교 조건 주의 사항
# 11.4.3.1 null 비교
# MySQL 에서는 null 값이 포함된 레코드도 인덱스로 관리된다
# SQL 표준에서 null 의 정의는 비교할 수 없는 값이다

select null = null;
select null <=> null;
select IF(null = null, 1, 0);
select IF(null is null, 1, 0);

# 위에 두 놈은 type: ref, index range scan, 아래 놈은 index full scan
# null 비교에는 가급적 is null 연산자 사용할 것
explain
select *
from titles
where to_date is null;

explain
select *
from titles
where isnull(to_date);

explain
select *
from titles
where isnull(to_date) = 1;

# 11.4.3.2 문자열 & 숫자 비교
# 타입에 주의해야 한다
explain
select *
from employees
where emp_no = 10001;

explain
select *
from employees
where first_name = 'Smith';

# 문자열을 숫자로 변환한 후 비교하기 때문에 특별한 성능 저하 X
explain
select *
from employees
where emp_no = '10001';

# MySQL 에서 숫자 > 문자 우선순위이므로 문자열 컬럼에 숫자 비교를 갈겨버리면 인덱스 컬럼이 변형되는 결과가 나오므로 인덱스 타지 못함
explain
select *
from employees
where first_name = 10001;

# 11.4.3.3 날짜 비교
# 11.4.3.3.1 DATE & DATETIME 문자열 비교
explain
select count(*)
from employees
where hire_date > str_to_date('2011-07-23', '%Y-%m-%d');

explain
select count(*)
from employees
where hire_date > '2011-07-23';

# 11.4.3.3.2 DATE & DATETIME 비교
# DATE -> DATETIME 변환 후 비교 수행, 얘네는 성능 차이는 없고 결과값에 주의해서 사용
explain
select count(*)
from employees
where hire_date > Date(now());

# 11.4.3.3.3 DATETIME & TIMESTAMP 비교
explain
select count(*)
from employees
where hire_date < '2011-07-23 11:10:12';

explain
select count(*)
from employees
where hire_date > unix_timestamp('1986-01-01 00:00:00');

# 11.4.3.4 Short-circuit Evaluation
explain
select count(*)
from salaries;

explain
select count(*)
from salaries
where convert_tz(from_date, '+00:00', '+09:00') > '1991-01-01';

explain
select count(*)
from salaries
where to_date < '1985-01-01';

# 1번 조건
explain
select count(*)
from salaries
where convert_tz(from_date, '+00:00', '+09:00') > '1991-01-01'
  and to_date < '1985-01-01';

# 2번 조건
explain
select count(*)
from salaries
where to_date < '1985-01-01'
  and convert_tz(from_date, '+00:00', '+09:00') > '1991-01-01';


# 이 실험에서는 차이가 없게 나왔지만 일반적으로 sub query 부분을 where 절 뒤쪽에 배치하는 것이 유리
explain
select *
from employees e
where e.first_name = 'Matt'
  and exists(select 1
             from salaries s
             where s.emp_no = e.emp_no
               and s.to_date > '1995-01-01'
             group by s.salary
             having count(*) > 1)
  and e.last_name = 'Aamodt';

explain
select *
from employees e
where e.first_name = 'Matt'
  and e.last_name = 'Aamodt'
  and exists(select 1
             from salaries s
             where s.emp_no = e.emp_no
               and s.to_date > '1995-01-01'
             group by s.salary
             having count(*) > 1);

flush status;
show status like 'Handler%';

# 11.4.4 DISTINCT
# unique 값 조회, join 특성을 잘못 이해한 결과로 distinct 를 남발하게 된다
# 테이블 간 연관관계가 1:1, 1:N 파악부터 하자

# 11.4.5 LIMIT n
# 상위 몇개만 짤라온다고 해서 성능 향상이 이뤄지는 것은 아니다
# 정렬이 수행되어야 상위 몇개를 알 수 있기 때문
explain
select *
from employees
where emp_no between 10001 and 10010
order by first_name
limit 0, 5;

# order, grouping, distinct 없는 상황에서는 10개만 읽어들이고 끝내므로 성능 향상
explain
select *
from employees
limit 0, 10;

# sql_mode=only_full_group_by error 발생
explain
select *
from employees
group by first_name
limit 0, 10;

SELECT @@sql_mode;

# distinct 수행하면서 10개 채워지면 가져오므로 성능 향상
explain
select distinct first_name
from employees
limit 0, 10;

# where 조건 타고 걸러진 후 order 타서 10개 가져오는데 성능 향상 크게 안 된다
explain
select *
from employees
where emp_no between 10001 and 11000
order by first_name
limit 0, 10;

# group by, order by, distinct 인덱스 타지 못 하는 경우에는 성능 향상 크게 이뤄지지 않고
# 얘네가 인덱스 타면서 결과 가져오면 limit 에 의한 성능 향상 이뤄짐

# limit 인자로 표현식이나 서브쿼리 불가
# select *
# from employees limit (100-10);

# 페이징 쿼리 주의사항
# limit n, m 상황, 얘는 빨리 조회됨
explain
select *
from salaries
order by salary
limit 0, 10;

# n, m 값이 커질수록 앞에 값들을 다 읽고 얘를 읽어야해서 성능 느려진다
explain
select *
from salaries
order by salary
limit 20000, 10;

# 뒤에 페이지를 읽으려면 where 로 필터 후 읽도록 한다
# 근디 이렇게 할라믄 where 조건 인자를 또 넣어줘야 하는 불편함이?!
explain
select *
from salaries
where salary >= 38864
  and not (salary = 38864 and emp_no <= 274049)
order by salary
limit 0, 10;

# 11.4.6 count()
# count(*) 모든 것을 읽어오라는 의미가 아니라 레코드 자체를 의미하므로 count(1), count(pk)와 동일한 성능
# 정확한 값이 필요한게 아니라면 통계정보를 이용하도록 한다
select table_schema,
       table_name,
       table_rows,
       (data_length + index_length) / 1024 / 1024 / 1024 as TABLE_SIZE_GB
from information_schema.TABLES
where TABLE_SCHEMA = 'employees'
  and TABLE_NAME = 'employees';

select count(*)
from employees;

# MySQL 8.0 이후부터 count(*) 에서의 order by 무시되도록 변경됨
# 이전 버전에서는 이와 같은 쿼리 날릴 시 쓸데없는 오버헤드 발생하므로 주의

# 11.4.7 JOIN
drop table tb_test1;
drop table tb_test2;

create table tb_test1
(
    user_id   int,
    user_type char(1) collate utf8mb4_general_ci,
    primary key (user_id)
);
create table tb_test2
(
    user_type char(1) collate utf8mb4_general_ci,
    type_desc varchar(10),
    primary key (user_type)
);

# 비교 조건에서 양쪽 컬럼의 데이터 타입이 달라 full scan 때림
explain
select *
from tb_test1 tb1,
     tb_test2 tb2
where tb1.user_type = tb2.user_type;


# 11.4.7.3 OUTER JOIN 성능, 주의사항
explain
select *
from employees e
         inner join dept_emp de on e.emp_no = de.emp_no
         inner join departments d on de.dept_no = d.dept_no and d.dept_name = 'Development';