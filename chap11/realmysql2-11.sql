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