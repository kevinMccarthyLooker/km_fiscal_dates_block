#Version: V1

###Block definition below
#base field variable set in manifest...# constant: my_base_field_for_financial_calendar {value: "${created_raw}"}
#Note: uses expression for date_add
#assumes all dialects can use same case when syntax
#doesn't label Fiscal quarter like 'FQ 1' as yet, just uses numbers
view: financial_calendar_extension {
  extension: required

  parameter: fiscal_calendar_selector {
    allowed_value: {value:"4-4-5"}
    allowed_value: {value:"4-5-4"}
    allowed_value: {value:"5-4-4"}
  }

  dimension: fiscal_calendar_type {
    sql:
    {% if fiscal_calendar_selector._parameter_value == "'4-4-5'"%}4-4-5
    {% elsif fiscal_calendar_selector._parameter_value == "'4-5-4'"%}4-5-4
    {% elsif fiscal_calendar_selector._parameter_value == "'5-4-4'"%}5-4-4
    {%else%}{{default_fiscal_calendar_type._sql |strip}}
    {%endif%}
        ;;
  }

### 00: Fields the implementer will configure {
  dimension_group: base_date {
    hidden: yes
    type: time
    timeframes: [raw,date,year]
#     sql: @{my_base_field_for_financial_calendar} ;;
    sql: OVERRIDE_ME ;;
  }
#   dimension: fiscal_calender_type_sql {
#     sql:
#     {% assign x = fiscal_calendar_type._sql | strip %}
#     {% assign x = x |replace:'-','+' %}
#     {% assign x = x |append:'+' |append:x |append:'+' |append:x |append:'+' |append:x %}
#     {{x}}
#         ;;
#   }
### } end section 00

### 00B: Initial helper fields based on what the implementer will configure {
  dimension: fiscal_calendar_type_sql_number {
    type: number
    sql: ({{fiscal_calendar_type._sql | strip |replace:'-','+' }}) ;;
  }
### } end section 00B

### 01: Get the first monday of the corresponding year as the key to subsequent calculations {
  dimension: jan_1_day {
#     hidden: yes
  convert_tz: no #base field would've already been converted
  type: date
  sql: ${base_date_year::date} ;;
}
dimension: jan_1_day_of_week_index {
#     hidden: yes
convert_tz: no #base field would've already been converted
type: date_day_of_week_index
sql: ${base_date_year::date} ;;
}
dimension: week1_day1 {
  hidden: yes
  convert_tz: no #base field would've already been converted
  type: date
  expression:if(${jan_1_day_of_week_index}=0,${jan_1_day},add_days((7-${jan_1_day_of_week_index}),${jan_1_day}));;
}

dimension: days_since_week1_day1 {
  hidden: yes
  convert_tz: no #base field would've already been converted
  type: duration_day
  sql_start: ${week1_day1::date} ;;
  sql_end:${base_date_date::date}  ;;
}
dimension: financial_day_of_year {
  type: number
  sql:
  case
    when ${days_since_week1_day1}<0 then ${days_since_week1_day1_one_year_prior}+1
    else ${days_since_week1_day1}+1
  end
      ;;
}

dimension: day_of_week_index {
  type: date_day_of_week_index
  convert_tz: no #base field would've already been converted
  sql: ${base_date_date::date} ;;
}
dimension: day_of_week {
  type: number
  sql: ${day_of_week_index}+1 ;;
}
### 01B All this to figure out if the first few days of the year should be week 52 or 53 {
dimension: jan_1_day_one_year_prior {
#     hidden: yes
convert_tz: no #base field would've already been converted
type: date
expression: add_years(-1,${jan_1_day}) ;;
}

dimension: jan_1_day_of_week_index_one_year_prior {
  hidden: yes
  convert_tz: no #base field would've already been converted
  type: date_day_of_week_index
  sql: ${jan_1_day_one_year_prior::date} ;;
}

dimension: week1_day1_one_year_prior {
  hidden: yes
  convert_tz: no #base field would've already been converted
  type: date
  expression:if(${jan_1_day_of_week_index_one_year_prior}=0,${jan_1_day_one_year_prior},add_days((7-${jan_1_day_of_week_index_one_year_prior}),${jan_1_day_one_year_prior}));;
}

dimension: days_since_week1_day1_one_year_prior {
  type: duration_day
  convert_tz: no #base field would've already been converted
  sql_start:${week1_day1_one_year_prior::date}  ;;
  sql_end:${base_date_date::date}  ;;
}
### } end section 01B
### } end section 01

### 02: periods ago type caclulations, useful for relative filters {
### 02B now based calculations helpers {
#note: these calcs were copied from the main ones... can we reuse that code better?
dimension_group: now_date {
  #     hidden: yes
  type: time
  timeframes: [raw,date,year]
  expression: now();;
}
dimension: now_jan_1_day {
  #     hidden: yes
  convert_tz: no #base field would've already been converted
  type: date
  sql: ${now_date_year::date} ;;
}
dimension: now_jan_1_day_of_week_index {
  #     hidden: yes
  convert_tz: no #base field would've already been converted
  type: date_day_of_week_index
  sql: ${now_date_year::date} ;;
}
dimension: now_week1_day1 {
  hidden: yes
  convert_tz: no #base field would've already been converted
  type: date
  expression:if(${now_jan_1_day_of_week_index}=0,${now_jan_1_day},add_days((7-${now_jan_1_day_of_week_index}),${now_jan_1_day}));;
}
dimension: now_days_since_week1_day1 {
  hidden: yes
  convert_tz: no #base field would've already been converted
  type: duration_day
  sql_start: ${now_week1_day1::date} ;;
  sql_end:${now_date_date::date}  ;;
}
dimension: now_days_since_week1_day1_one_year_prior {
  type: duration_day
  convert_tz: no #base field would've already been converted
  sql_start:${week1_day1_one_year_prior::date}  ;;
  sql_end:${now_date_date::date}  ;;
}
dimension: now_financial_year {
  type: number
  sql: ${now_date_year} - case when ${now_days_since_week1_day1}<0 then 1 else 0 end;;
}
dimension: now_financial_quarter_of_year {
  type: number
  sql:
    case
      when ${now_days_since_week1_day1}<0 or ${now_days_since_week1_day1}>=3*7*13 then 4
      else ${now_days_since_week1_day1}/(7*13)+1
    end ;;
}
dimension: now_financial_quarter_as_a_number {
  type: number
  sql: ${now_financial_year}*4+${now_financial_quarter_of_year} ;;
}
dimension: now_financial_month_of_year {
  type: number
  sql:
    {% assign calendar_type_sql = fiscal_calendar_type._sql | strip |replace:'-','+' %}
    {% assign calendar_type_sql = calendar_type_sql |append:'+' |append:calendar_type_sql |append:'+' |append:calendar_type_sql |append:'+' |append:calendar_type_sql %}
    case
    when ${now_days_since_week1_day1} is null then null
    when ${now_days_since_week1_day1}<0 then 12
    when ${now_days_since_week1_day1}<{{calendar_type_sql | slice: 0,1}}*7 then 1
    when ${now_days_since_week1_day1}<({{calendar_type_sql | slice: 0,3}})*7 then 2
    when ${now_days_since_week1_day1}<({{calendar_type_sql | slice: 0,5}})*7 then 3
    when ${now_days_since_week1_day1}<({{calendar_type_sql | slice: 0,7}})*7 then 4
    when ${now_days_since_week1_day1}<({{calendar_type_sql | slice: 0,9}})*7 then 5
    when ${now_days_since_week1_day1}<({{calendar_type_sql | slice: 0,11}})*7 then 6
    when ${now_days_since_week1_day1}<({{calendar_type_sql | slice: 0,13}})*7 then 7
    when ${now_days_since_week1_day1}<({{calendar_type_sql | slice: 0,15}})*7 then 8
    when ${now_days_since_week1_day1}<({{calendar_type_sql | slice: 0,17}})*7 then 9
    when ${now_days_since_week1_day1}<({{calendar_type_sql | slice: 0,19}})*7 then 10
    when ${now_days_since_week1_day1}<({{calendar_type_sql | slice: 0,21}})*7 then 11
    else 12
    end
    ;;
}
dimension: now_financial_month_as_a_number {
  type: number
  sql: ${now_financial_year}*12+${now_financial_month_of_year} ;;
}
dimension: now_financial_week_of_year {
  type: number
  sql:
    case
      when ${now_days_since_week1_day1}<0 then ${now_days_since_week1_day1_one_year_prior}/7+1
      else ${now_days_since_week1_day1}/7+1
    end;;
}
dimension: dummy_date {
  type: date
  convert_tz: no
  expression: date(1900,01,01);;
}
#using this date since it was a monday on a jan 1
dimension: now_days_since_2019_01_01 {
  type: duration_day
  convert_tz: no #base field would've already been converted
  sql_start:${dummy_date::date}  ;;
  sql_end:${now_date_date::date}  ;;
}
#misnomer 'financial' for this calculation
dimension: financial_days_since_2019_01_01 {
  type: duration_day
  convert_tz: no #base field would've already been converted
  sql_start:${dummy_date::date}  ;;
  sql_end:${base_date_date::date}  ;;
}
### } end section 02B
dimension: financial_years_ago {
  type: number
  sql: ${now_financial_year::number}-${financial_year::number} ;;
}
dimension: financial_quarters_ago {
  type: number
  sql: ${now_financial_quarter_as_a_number}-${financial_quarter_as_a_number} ;;
}
dimension: financial_months_ago {
  type: number
  sql: ${now_financial_month_as_a_number}-${financial_month_as_a_number} ;;
}
dimension: financial_weeks_ago {
  type: number
  sql:${now_days_since_2019_01_01}/7-${financial_days_since_2019_01_01}/7  ;;
}
### } end section 02

### 03 Calculate and show the fiscal calendar features {
dimension: financial_year {
  type: number
  sql: ${base_date_year} - case when ${days_since_week1_day1}<0 then 1 else 0 end;;
}
#quarter fields
dimension: financial_year_quarter_label {
  type: string
  expression: concat(${financial_year},"-",${financial_quarter_of_year_for_label});;
}
dimension: financial_quarter_of_year {
  type: number
  sql:
  case
    when ${days_since_week1_day1}<0 or ${days_since_week1_day1}>=3*7*({{fiscal_calendar_type._sql | strip |replace:'-','+' }}) then 4
    else ${days_since_week1_day1}/(7*({{fiscal_calendar_type._sql | strip |replace:'-','+' }}))+1
  end ;;
}
dimension: financial_quarter_of_year_for_label {
  type: number
  sql:
    case
      when ${days_since_week1_day1}<0 or ${days_since_week1_day1}>=3*7*({{fiscal_calendar_type._sql | strip |replace:'-','+' }}) then 4
      else ${days_since_week1_day1}/(7*({{fiscal_calendar_type._sql | strip |replace:'-','+' }}))+1
    end ;;
}

dimension: financial_quarter_as_a_number {
  type: number
  sql: ${financial_year}*4+${financial_quarter_of_year} ;;
}

#month fields
dimension: financial_year_quarter_month_label {
  type: string
  expression: concat(${financial_year},"-",${financial_quarter_of_year_for_label},"-",${financial_month_of_quarter});;
}
#can this be more efficient?
dimension: financial_month_of_year {
  type: number
  sql:
    {% assign calendar_type_sql = fiscal_calendar_type._sql | strip |replace:'-','+' %}
    {% assign calendar_type_sql = calendar_type_sql |append:'+' |append:calendar_type_sql |append:'+' |append:calendar_type_sql |append:'+' |append:calendar_type_sql %}
        case
         when ${days_since_week1_day1} is null then null
         when ${days_since_week1_day1}<0 then 12
         when ${days_since_week1_day1}<{{calendar_type_sql | slice: 0,1}}*7 then 1
         when ${days_since_week1_day1}<({{calendar_type_sql | slice: 0,3}})*7 then 2
         when ${days_since_week1_day1}<({{calendar_type_sql | slice: 0,5}})*7 then 3
         when ${days_since_week1_day1}<({{calendar_type_sql | slice: 0,7}})*7 then 4
         when ${days_since_week1_day1}<({{calendar_type_sql | slice: 0,9}})*7 then 5
         when ${days_since_week1_day1}<({{calendar_type_sql | slice: 0,11}})*7 then 6
         when ${days_since_week1_day1}<({{calendar_type_sql | slice: 0,13}})*7 then 7
         when ${days_since_week1_day1}<({{calendar_type_sql | slice: 0,15}})*7 then 8
         when ${days_since_week1_day1}<({{calendar_type_sql | slice: 0,17}})*7 then 9
         when ${days_since_week1_day1}<({{calendar_type_sql | slice: 0,19}})*7 then 10
         when ${days_since_week1_day1}<({{calendar_type_sql | slice: 0,21}})*7 then 11
         else 12
        end
          ;;
}
dimension: financial_month_of_quarter {
  type: number
  expression:
  if(mod(${financial_month_of_year},3)=0
  ,3
  ,mod(${financial_month_of_year},3)
  )
      ;;
}
dimension: financial_month_as_a_number {
  type: number
  sql: ${financial_year}*12+${financial_month_of_year} ;;
}

#week fields
dimension: financial_year_quarter_month_week_label {
  required_fields: [financial_week_of_month,financial_month_of_quarter,financial_quarter_of_year,financial_year]
  type: string
  expression: concat(${financial_year},"-",${financial_quarter_of_year},"-",${financial_month_of_quarter},"-",${financial_week_of_month_for_label});;
}
#need a special label copy: can't use a field with liquid AND have an expression that uses it in the query: the liquid does not evaluate properly
dimension: financial_week_of_year {
  type: number
  sql:
  case
    when ${days_since_week1_day1}<0 then ${days_since_week1_day1_one_year_prior}/7+1
    else ${days_since_week1_day1}/7+1
  end;;
}
dimension: financial_week_of_quarter {
  type: number
  sql: ((${financial_day_of_year}-1)-((${financial_quarter_of_year}-1)*7*13))/7+1;;
}
dimension: financial_week_of_month {
  type: number
  sql:
  {% assign calendar_type_sql = fiscal_calendar_type._sql | strip |replace:'-','+' %}
  case
    when ${financial_week_of_quarter} is null then null
    when ${financial_week_of_quarter}<={{calendar_type_sql | slice: 0,1}} then ${financial_week_of_quarter}
    when ${financial_week_of_quarter}<=({{calendar_type_sql | slice: 0,3}}) then ${financial_week_of_quarter} - ({{calendar_type_sql | slice: 0,1}})
    else ${financial_week_of_quarter} - ({{calendar_type_sql | slice: 0,3}})
  end
      ;;
}
dimension: financial_week_of_month_for_label {
  type: number
  sql:
  {% assign calendar_type_sql = fiscal_calendar_type._sql | strip |replace:'-','+' %}
  case
    when ${financial_week_of_quarter} is null then null
    when ${financial_week_of_quarter}<={{calendar_type_sql | slice: 0,1}} then ${financial_week_of_quarter}
    when ${financial_week_of_quarter}<=({{calendar_type_sql | slice: 0,3}}) then ${financial_week_of_quarter} - ({{calendar_type_sql | slice: 0,1}})
    else ${financial_week_of_quarter} - ({{calendar_type_sql | slice: 0,3}})
  end
      ;;
}

#day fields
dimension: financial_day_of_quarter {
  type: number
  sql:((${financial_day_of_year}-1)-((${financial_quarter_of_year}-1)*7*13))+1;;
}
dimension: financial_day_of_month {
  type: number
  sql: (${financial_week_of_month}-1)*7+${day_of_week} ;;
}

#or should this be order by first day of financial week? #can't do difference math on this, but at least it's sortable
#   dimension: financial_year_and_quarter_week_of_quarter_sort {
#     type: number
#     sql:${fiscal_dates.financial_year}*1000+${fiscal_dates.financial_quarter_of_year}*100+${financial_week_of_quarter};;
#   }
#   dimension: financial_year_and_quarter_week_of_quarter_label {
#     order_by_field: financial_year_and_quarter_week_of_quarter_sort
#     type: string
#     expression: concat(${fiscal_dates.financial_year},"-",${fiscal_dates.financial_quarter_of_year},"-",${financial_week_of_quarter});;
#   }

#first day fields
dimension: first_day_of_financial_year {
  type: date
  convert_tz: no
  expression:
  if(${days_since_week1_day1}<0
  ,${week1_day1_one_year_prior}
  ,${week1_day1}
  )
  ;;
}
dimension: first_day_of_financial_quarter {
  required_fields: [fiscal_calendar_type_sql_number]
  convert_tz: no
  type: date
  expression:
  if(${days_since_week1_day1}<0
  ,add_days((4-1)*13*7,${week1_day1_one_year_prior})
  ,add_days((${financial_quarter_of_year}-1)*7*${fiscal_calendar_type_sql_number},${week1_day1})
  )
      ;;
  #     expression:
  #     if(${fiscal_dates.days_since_week1_day1}<0
  #     ,add_days((4-1)*13*7,${fiscal_dates.week1_day1_one_year_prior})
  #     ,add_days((${fiscal_dates.financial_quarter_of_year}-1)*7*${fiscal_dates.fiscal_calendar_type_sql_number},${fiscal_dates.week1_day1})
  #     )
  #     ;;
  }

  dimension: first_day_of_financial_month {
    convert_tz: no
    type: date
#     sql:
#     {% assign calendar_type_sql = fiscal_calendar_type._sql | strip |replace:'-','+' %}
#     {% assign calendar_type_sql = calendar_type_sql |append:'+' |append:calendar_type_sql |append:'+' |append:calendar_type_sql |append:'+' |append:calendar_type_sql %}
#     case
#     when ${financial_day_of_year} is null then null
#     when ${financial_day_of_year}<0 then 0
#     when ${financial_day_of_year}<({{calendar_type_sql | slice: 0,1}})*7+1 then ${financial_day_of_year}
#     when ${financial_day_of_year}<({{calendar_type_sql | slice: 0,3}})*7+1 then ${financial_day_of_year} - ({{calendar_type_sql | slice: 0,3}}-1)*7
#     when ${financial_day_of_year}<({{calendar_type_sql | slice: 0,5}})*7+1 then ${financial_day_of_year} - ({{calendar_type_sql | slice: 0,5}}-1)*7
#     when ${financial_day_of_year}<({{calendar_type_sql | slice: 0,7}})*7+1 then ${financial_day_of_year} - ({{calendar_type_sql | slice: 0,7}}-1)*7
#     when ${financial_day_of_year}<({{calendar_type_sql | slice: 0,9}})*7+1 then ${financial_day_of_year} - ({{calendar_type_sql | slice: 0,9}}-1)*7
#     when ${financial_day_of_year}<({{calendar_type_sql | slice: 0,11}})*7+1 then ${financial_day_of_year} - ({{calendar_type_sql | slice: 0,11}}-1)*7
#     when ${financial_day_of_year}<({{calendar_type_sql | slice: 0,13}})*7+1 then ${financial_day_of_year} - ({{calendar_type_sql | slice: 0,13}}-1)*7
#     when ${financial_day_of_year}<({{calendar_type_sql | slice: 0,15}})*7+1 then ${financial_day_of_year} - ({{calendar_type_sql | slice: 0,15}}-1)*7
#     when ${financial_day_of_year}<({{calendar_type_sql | slice: 0,17}})*7+1 then ${financial_day_of_year} - ({{calendar_type_sql | slice: 0,17}}-1)*7
#     when ${financial_day_of_year}<({{calendar_type_sql | slice: 0,19}})*7+1 then ${financial_day_of_year} - ({{calendar_type_sql | slice: 0,19}}-1)*7
#     when ${financial_day_of_year}<({{calendar_type_sql | slice: 0,21}})*7+1 then ${financial_day_of_year} - ({{calendar_type_sql | slice: 0,21}}-1)*7
#     else 12
#     end
#     ;;
# expression: add_days(-1*(${financial_day_of_month}-1),${fiscal_dates.base_date_date});;
    expression: add_days(-1*(${financial_day_of_month}-1),${base_date_date_for_expression});;
  }
  dimension: base_date_date_for_expression {
    type: date
    convert_tz: no
    datatype: date
    sql: ${base_date_date::date} ;;
  }
  dimension: first_day_of_financial_week {
    convert_tz: no
    type: date
    expression: add_days(-1*(${day_of_week}-1),${base_date_date_for_expression});;

  }


###}end section 03

### 04 For validation support {
  measure: count_distinct_days {
    type: count_distinct
    sql: ${base_date_date} ;;
  }
  measure: range_days {
    type: string
    sql: min(${base_date_date}) || '-' || max(${base_date_date}) ;;
  }
  measure: min_date {
    convert_tz: no
    type: date
    sql: min(${base_date_date});;
  }
  measure: max_date {
    convert_tz: no
    type: date
    sql:max(${base_date_date}) ;;
  }
  measure: min_day_of_year {
    convert_tz: no
    type: date_day_of_year
    sql: min(${base_date_date});;
  }
  measure: max_day_of_year {
    convert_tz: no
    type: date_day_of_year
    sql:max(${base_date_date}) ;;
  }
  measure: drill_to_daily_calculations_support {
    type: string
    sql: concat(${count_distinct_days}, ' days. Click for each qualifying days fiscal classifications') ;;

    drill_fields: [fiscal_dates.base_date_date, fiscal_dates.financial_year, fiscal_dates.financial_years_ago,
      fiscal_dates.first_day_of_financial_year, fiscal_dates.financial_quarter_of_year,
      fiscal_dates.financial_month_of_year, fiscal_dates.financial_week_of_year, fiscal_dates.financial_day_of_year,
      fiscal_dates.financial_year_quarter_label, fiscal_dates.financial_quarters_ago,
      fiscal_dates.first_day_of_financial_quarter, fiscal_dates.financial_month_of_quarter,
      fiscal_dates.financial_week_of_quarter, fiscal_dates.financial_day_of_quarter,
      fiscal_dates.financial_year_quarter_month_label, fiscal_dates.financial_months_ago,
      fiscal_dates.first_day_of_financial_month, fiscal_dates.financial_week_of_month,
      fiscal_dates.financial_day_of_month, fiscal_dates.financial_year_quarter_month_week_label,
      fiscal_dates.financial_weeks_ago, fiscal_dates.first_day_of_financial_week, fiscal_dates.day_of_week,
      fiscal_dates.week1_day1, fiscal_dates.range_days, fiscal_dates.count]
#     html: <a href>{{linked_value}}</a> ;;
      html: <a href="{{link}}" target="_blank">{{rendered_value}}</a> ;;
    }
### } end section 04
  }
