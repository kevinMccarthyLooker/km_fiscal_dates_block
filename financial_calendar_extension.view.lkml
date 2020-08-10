#Version: V1.2
## Version History
# Fix applied adding ::number to numeric fields like ${now_date_year::number}
# added required fields on jan_1 day for athena using string in expression instead of date

###Block definition below
#base field variable set in manifest...# constant: my_base_field_for_financial_calendar {value: "${created_raw}"}
#Note: uses expression for date_add
#assumes all dialects can use same case when syntax
#doesn't label Fiscal quarter like 'FQ 1' as yet, just uses numbers
view: financial_calendar_extension {
  extension: required

### 00: Fields the implementer will configure {
  dimension_group: base_date {
    type: time
    timeframes: [raw,date,year,day_of_year,day_of_week_index]
    sql: OVERRIDE_ME ;;
  }
  parameter: fiscal_calendar_selector {
    allowed_value: {value:"4-4-5"}
    allowed_value: {value:"4-5-4"}
    allowed_value: {value:"5-4-4"}
    default_value: "4-4-5"
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
### } end section 00

### 00B: Helper fields... required to support subsequent expression based calculations. Never expect these to be visible {
  dimension: fiscal_calendar_type_sql_number {
    type: number
    sql: ({{fiscal_calendar_type._sql | strip |replace:'-','+' }}) ;;
  }
### } end section 00B

### 01: Core Calculations. Never expect these to be visible {
  ### 01B: Get the first monday of the date's year (key to subsequent calculations) {
  dimension: jan_1_day {
    type: date  convert_tz: no #base field would've already been converted
    sql: ${base_date_year::date} ;;
  }
  dimension: jan_1_day_of_week_index {
    type: date_day_of_week_index  convert_tz: no #base field would've already been converted
    sql: ${base_date_year::date} ;;
  }
  dimension: jan_1_day_to_first_monday_number_days {
    type: number #type matters cause it's used in an expression
    expression:mod(7-${jan_1_day_of_week_index},7);;
  }
  dimension: first_monday {
    type: date  convert_tz: no #base field would've already been converted
    expression:add_days(${jan_1_day_to_first_monday_number_days},${jan_1_day});;
  }
  dimension: days_since_first_monday {
    type: number
    sql: ${base_date_day_of_year::number}-${jan_1_day_to_first_monday_number_days}-1 ;;
  }
  ### } end section 01B

  ### 01C: All this to help figure out if the first few days of the year should be week 52 or 53 {
  dimension: one_year_prior_jan_1_day {
    type: date  convert_tz: no #base field would've already been converted
    expression: add_years(-1,${jan_1_day}) ;;
  }
  dimension: one_year_prior_jan_1_day_of_week_index {
    type: date_day_of_week_index  convert_tz: no #base field would've already been converted
    sql: ${one_year_prior_jan_1_day::date} ;;
  }
  dimension: one_year_prior_jan_1_day_to_first_monday_number_days {
    type: number
    expression:mod(7-${one_year_prior_jan_1_day_of_week_index},7);;
  }
  dimension: one_year_prior_first_monday {
    required_fields: [one_year_prior_jan_1_day] #8/8 athena was treating it as a string
    type: date  convert_tz: no #base field would've already been converted
    expression:add_days(${one_year_prior_jan_1_day_to_first_monday_number_days},${one_year_prior_jan_1_day});;#   expression:if(${one_year_prior_jan_1_day_of_week_index}=0,${one_year_prior_jan_1_day},add_days((7-${one_year_prior_jan_1_day_of_week_index}),${one_year_prior_jan_1_day}));;
  }
  dimension: one_year_prior_days_since_first_monday {
    type: duration_day  convert_tz: no #base field would've already been converted
    sql_start:${one_year_prior_first_monday::date}  ;;
    sql_end:${base_date_date::date}  ;;
  }
  ### } end section 01C

  ### 01D: Similar calculations but based on now, used in comparison later to create financial months ago, etc {
  dimension: now_jan_1_day {
    type: date  convert_tz: no #base field would've already been converted
    sql: ${now_date_year::date} ;;
  }
  dimension: now_jan_1_day_of_week_index {
    type: date_day_of_week_index  convert_tz: no #base field would've already been converted
    sql: ${now_date_year::date} ;;
  }
  dimension: now_jan_1_day_to_first_monday_number_days {
    type: number
    expression:mod(7-${now_jan_1_day_of_week_index},7);;
  }
  dimension: now_first_monday {
    type: date  convert_tz: no #base field would've already been converted
    expression:add_days(${now_jan_1_day_to_first_monday_number_days},${now_jan_1_day});; #     expression:if(${now_jan_1_day_of_week_index}=0,${now_jan_1_day},add_days((7-${now_jan_1_day_of_week_index}),${now_jan_1_day}));;
  }
  dimension: now_days_since_first_monday {
    type: number
    sql: ${now_date_day_of_year::number}-${now_jan_1_day_to_first_monday_number_days}-1 ;; #     sql_start: ${now_first_monday::date} ;;#     sql_end:${now_date_date::date}  ;;
  }
  ### } end section 01D

  ### 01E: Additional now based calculation helpers {
  dimension_group: now_date {
    type: time
    timeframes: [raw,date,year,day_of_year]
    expression: now();;
  }
  dimension: now_days_since_first_monday_one_year_prior {
    type: duration_day
    sql_start:${one_year_prior_first_monday::date};; sql_end:${now_date_date::date};;
  }
  dimension: now_financial_year {
    type: number
    sql: ${now_date_year::number} - case when ${now_days_since_first_monday}<0 then 1 else 0 end;;
  }
  dimension: now_financial_quarter_of_year {
    type: number
    sql:
    floor(
      case
        when ${now_days_since_first_monday}<0 then 4
        when ${now_days_since_first_monday}>=3*7*13 then 4
        else ${now_days_since_first_monday}/(7*13)+1
      end
    );;
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
    when ${now_days_since_first_monday} is null then null
    when ${now_days_since_first_monday}<0 then 12
    when ${now_days_since_first_monday}<{{calendar_type_sql | slice: 0,1}}*7 then 1
    when ${now_days_since_first_monday}<({{calendar_type_sql | slice: 0,3}})*7 then 2
    when ${now_days_since_first_monday}<({{calendar_type_sql | slice: 0,5}})*7 then 3
    when ${now_days_since_first_monday}<({{calendar_type_sql | slice: 0,7}})*7 then 4
    when ${now_days_since_first_monday}<({{calendar_type_sql | slice: 0,9}})*7 then 5
    when ${now_days_since_first_monday}<({{calendar_type_sql | slice: 0,11}})*7 then 6
    when ${now_days_since_first_monday}<({{calendar_type_sql | slice: 0,13}})*7 then 7
    when ${now_days_since_first_monday}<({{calendar_type_sql | slice: 0,15}})*7 then 8
    when ${now_days_since_first_monday}<({{calendar_type_sql | slice: 0,17}})*7 then 9
    when ${now_days_since_first_monday}<({{calendar_type_sql | slice: 0,19}})*7 then 10
    when ${now_days_since_first_monday}<({{calendar_type_sql | slice: 0,21}})*7 then 11
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
    floor(
    case
      when ${now_days_since_first_monday}<0 then ${now_days_since_first_monday_one_year_prior}/7+1
      else ${now_days_since_first_monday}/7+1
    end
    );;
  }
  dimension: reference_date {
    type: date  convert_tz: no
    expression: date(1900,01,01);;
  }
  #using this date since it was a monday on a jan 1 and long ago.  calculations against an earlier date where this would be negative will be off
  dimension: now_days_since_reference_date {
    type: duration_day  convert_tz: no #base field would've already been converted
    sql_start:${reference_date::date};; sql_end:${now_date_date::date};;
  }
  dimension: days_since_reference_date {
    type: duration_day  convert_tz: no #base field would've already been converted
    sql_start:${reference_date::date};; sql_end:${base_date_date::date};;
  }
  ### } end section 01E
### } end section 01

### 02: Additional framings, useful for filtering and such {
  ### 02B: Periods ago type caclulations, useful for relative filters
  dimension: financial_years_ago {
    type: number
    sql: ${now_financial_year::number}-${financial_year::number} ;;
  }
  dimension: financial_quarters_ago {
    type: number
    sql: ${now_financial_quarter_as_a_number}-(${financial_year}*4+${financial_quarter_of_year}) ;;
  }
  dimension: financial_months_ago {
    type: number
    sql: ${now_financial_month_as_a_number}-(${financial_year}*12+${financial_month_of_year}) ;;
  }
  dimension: financial_weeks_ago {
    type: number
    sql:floor(${now_days_since_reference_date}/7)-floor(${days_since_reference_date}/7)  ;;
  }
  ### } end section 02B
  ### 02C: Fully Qualified Label Fields {
  dimension: financial_year_quarter_label {
    type: string
    expression: concat(${financial_year},"-",${financial_quarter_of_year_for_expression});;
  }
  dimension: financial_year_quarter_month_label {
    type: string
    expression: concat(${financial_year},"-",${financial_quarter_of_year_for_expression},"-",${financial_month_of_quarter});;
  }
  dimension: financial_year_quarter_month_week_label {
    required_fields: [financial_week_of_month,financial_month_of_quarter,financial_quarter_of_year,financial_year]
    type: string
    expression: concat(${financial_year},"-",${financial_quarter_of_year},"-",${financial_month_of_quarter},"-",${financial_week_of_month_for_expression});;
  }
  ### } end section 02C
### Section 02D: first day fields {
  dimension: first_day_of_financial_year {
    required_fields: [fiscal_calendar_type_sql_number,first_monday,one_year_prior_first_monday]
    type: date  convert_tz: no
    expression:
    if(${days_since_first_monday}<0
    ,${one_year_prior_first_monday}
    ,${first_monday}
    )
    ;;
  }
  dimension: first_day_of_financial_quarter {
    required_fields: [fiscal_calendar_type_sql_number,first_monday,one_year_prior_first_monday,financial_quarter_of_year]
    type: date  convert_tz: no
    expression:
    if(${days_since_first_monday}<0
    ,add_days((4-1)*13*7,${one_year_prior_first_monday})
    ,add_days((${financial_quarter_of_year}-1)*7*${fiscal_calendar_type_sql_number},${first_monday})
    )
        ;;
  }
  dimension: first_day_of_financial_month {
    type: date  convert_tz: no
    expression: add_days(-1*(${financial_day_of_month}-1),${base_date_date_for_expression});;
  }
  #extra copy of field so we can use the raw one and an expression at the same time
  dimension: base_date_date_for_expression {
    type: date  convert_tz: no  datatype: date
    sql: ${base_date_date::date} ;;
  }
  dimension: base_date_day_of_week_index_for_expression {
    type: number
    sql: ${base_date_day_of_week_index} ;;
  }
  dimension: first_day_of_financial_week {
    type: date  convert_tz: no
    expression: add_days(-1*(${base_date_day_of_week_index_for_expression}),${base_date_date_for_expression});;
  }
  ###} - end section 02D
### } end section 02

### 03 Financial calendar numeric fields ('..._of_year', '..._of_month', etc) {
  ### 03B: Year and Quarter Number fields {
  dimension: financial_year {
    type: number
    sql: ${base_date_year::number} - case when ${days_since_first_monday}<0 then 1 else 0 end;;
  }
  dimension: financial_quarter_of_year {
    type: number
    sql:
    floor(
      case
        when ${days_since_first_monday}<0 then 4
        when ${days_since_first_monday}>=3*7*13 then 4
        else ${days_since_first_monday}/(7*13)+1
      end
    );;
  }
  #duplicate copy becasue a field can't be selected and used in expression at same time
  dimension: financial_quarter_of_year_for_expression {
    type: number
    sql:
    floor(
      case
        when ${days_since_first_monday}<0 then 4
        when ${days_since_first_monday}>=3*7*13 then 4
        else ${days_since_first_monday}/(7*13)+1
      end
    );;
  }
  ### } end section 03B

  ### 03C: Month Number fields {
  dimension: financial_month_of_year {
    type: number
    sql:
    {% assign calendar_type_sql = fiscal_calendar_type._sql | strip |replace:'-','+' %}
    {% assign calendar_type_sql = calendar_type_sql |append:'+' |append:calendar_type_sql |append:'+' |append:calendar_type_sql |append:'+' |append:calendar_type_sql %}
        case
         when ${days_since_first_monday} is null then null
         when ${days_since_first_monday}<0 then 12
         when ${days_since_first_monday}<{{calendar_type_sql | slice: 0,1}}*7 then 1
         when ${days_since_first_monday}<({{calendar_type_sql | slice: 0,3}})*7 then 2
         when ${days_since_first_monday}<({{calendar_type_sql | slice: 0,5}})*7 then 3
         when ${days_since_first_monday}<({{calendar_type_sql | slice: 0,7}})*7 then 4
         when ${days_since_first_monday}<({{calendar_type_sql | slice: 0,9}})*7 then 5
         when ${days_since_first_monday}<({{calendar_type_sql | slice: 0,11}})*7 then 6
         when ${days_since_first_monday}<({{calendar_type_sql | slice: 0,13}})*7 then 7
         when ${days_since_first_monday}<({{calendar_type_sql | slice: 0,15}})*7 then 8
         when ${days_since_first_monday}<({{calendar_type_sql | slice: 0,17}})*7 then 9
         when ${days_since_first_monday}<({{calendar_type_sql | slice: 0,19}})*7 then 10
         when ${days_since_first_monday}<({{calendar_type_sql | slice: 0,21}})*7 then 11
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
  ### } end section 03C

  ### 03D: Week Number fields {
  dimension: financial_week_of_year {
    type: number
    sql:
    floor(
      case
        when ${days_since_first_monday}<0 then ${one_year_prior_days_since_first_monday}/7+1
        else ${days_since_first_monday}/7+1
      end
    );;
  }
  dimension: financial_week_of_quarter {
    type: number
    sql: floor((${financial_day_of_quarter}-1)/7+1) ;; #     sql: ((${financial_day_of_year}-1)-((${financial_quarter_of_year}-1)*7*13))/7+1;;
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
  #copy because we can't use the field itself and the field as part of an expression calculation at the same time
  dimension: financial_week_of_month_for_expression {
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
  ### } end section 03D

  ### 03E: Day Number fields {
  dimension: financial_day_of_year {
    type: number
    sql:
    case when ${days_since_first_monday}<0 then ${one_year_prior_days_since_first_monday}+1
         else ${days_since_first_monday}+1
    end
        ;;
  }
  dimension: financial_day_of_quarter {
    type: number
    sql:((${financial_day_of_year})-((${financial_quarter_of_year}-1)*7*13));;
  }
  dimension: financial_day_of_month {
    type: number
    sql: (${financial_week_of_month}-1)*7+${base_date_day_of_week_index}+1 ;;
  }
  dimension: day_of_week {
    type: number
    sql: ${base_date_day_of_week_index}+1 ;;
  }
  ### } end section 03E
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

    drill_fields: [base_date_date, financial_year, financial_years_ago,
      first_day_of_financial_year, financial_quarter_of_year,
      financial_month_of_year, financial_week_of_year, financial_day_of_year,
      financial_year_quarter_label, financial_quarters_ago,
      first_day_of_financial_quarter, financial_month_of_quarter,
      financial_week_of_quarter, financial_day_of_quarter,
      financial_year_quarter_month_label, financial_months_ago,
      first_day_of_financial_month, financial_week_of_month,
      financial_day_of_month, financial_year_quarter_month_week_label,
      financial_weeks_ago, first_day_of_financial_week, day_of_week,
      first_monday, range_days, count]
#     html: <a href>{{linked_value}}</a> ;;
      html: <a href="{{link}}" target="_blank">{{rendered_value}}</a> ;;
    }
### } end section 04
  }

###adding required fields to each expression based field
