# Data from https://datacatalog.cookcountyil.gov/Courts/State-s-Attorney-Felony-Cases-Disposition-Outcomes/cqdb-r84f

library(dplyr)
library(ggplot2)


#' @return data frame based on the original dataset from:
#' https://datacatalog.cookcountyil.gov/Courts/State-s-Attorney-Felony-Cases-Disposition-Outcomes/cqdb-r84f
#' The data are disaggregated by race, and a few new columns were added for ease of analysis.
#' See the comments below explaining the new columns - they're intended to make it easier to
#' analyze guilty pleas and cases that were "dropped" in some way.
prep_disaggregated <- function() {
  df <- read.csv('State_s_Attorney_Felony_Cases_-_Disposition_Outcomes_By_Offense_Type_and_Defendant_Race.csv')
  # Exclude blank dispositions, there are a few
  df <- df %>%
    filter(DISPOSITION != '') %>%
    group_by(YEAR, DISPOSITION, OFFENSE.TYPE) %>%
    summarise(total_defendants=sum(DEFENDANT.COUNT)) %>%
    mutate(
      # There are 4 "plea of guilty..." dispositions - group all of these in the `pled_guilty` column
      pled_guilty = grepl('^Plea', DISPOSITION),
      # "Nolle Prosecution" - decided not to prosecute at this time. Note this is different from a straight
      # dismissal.
      # "Finding of no probable cause" - there are a lot of these, I suspect because narcotics cases don't need
      # to go through the same initiation process as other cases. From the report itself:
      # "Cases may also be indicted by a grand jury or, in narcotics cases, filed directly by law enforcement."
      nol_pros_or_no_prob_cause = DISPOSITION %in% c('Nolle Prosecution', 'FNPC')
    )
  
  return(df)
}

narcotics_plea_rates <- function(df) {
  # What % of drug cases were pled guilty in any given year?
  # Weird! Surprised that:
  # 1. It's a very low % - between 38 - 50%. Meaning another 50% went to trial, or had dismissed?
  # 2. It seems to have increased over time
  yearly_narcos <- df %>%
    filter(OFFENSE.TYPE == 'Narcotics') %>%
    group_by(YEAR) %>%
    summarise(
      total_cases = sum(total_defendants),
      pled_guilty = sum(total_defendants[pled_guilty]),
      pct_pled = pled_guilty / total_cases
    )
  print('Yearly narcotics cases - % of cases pled guilty')
  print(yearly_narcos)
  
  # Leads to the question - what's happening in all of those other cases?
  non_pled_narcos <- df %>%
    filter(OFFENSE.TYPE == 'Narcotics') %>%
    filter(!pled_guilty)
  
  # To get a quick idea - let's just look at the most common disposition in 2015
  print('Most common dispositions in 2015:')
  print(head(non_pled_narcos %>%
               filter(YEAR == '2015') %>%
               arrange(desc(total_defendants)), 10))
  # Ah, so the two most common other dispositions were:
  # "Nolle Prosecution" (SAO chose not to proceed)
  # "FNPC" (Finding of no probable cause)
  # Both of these seem to mean "the cases was dismissed"
  
  # So what happens when we filter those out of our original counts? Will that get us to the
  # high rates of pleas that we had expected?
  not_dismissed_narcos <- df %>%
    filter(OFFENSE.TYPE == 'Narcotics') %>%
    filter(!DISPOSITION %in% c('Nolle Prosecution', 'FNPC'))
  
  not_dismissed_yearly_narco_summary <- not_dismissed_narcos %>%
    group_by(YEAR) %>%
    summarise(
      total_cases = sum(total_defendants),
      pled_guilty = sum(total_defendants[pled_guilty]),
      pct_pled = pled_guilty / total_cases
    )
  print('Summary of not-dismissed cases, by whether they were pled guilty')
  print(not_dismissed_yearly_narco_summary)
}

narcotics_vs_other_plea_rates <- function(df) {
  # Expects to have a "pled_guilty" column already present
  plea_rate_by_narco <- df %>%
    mutate(narcotics_case = OFFENSE.TYPE == 'Narcotics') %>%
    group_by(narcotics_case) %>%
    summarise(
      total_cases = sum(total_defendants),
      num_pled_guilty = sum(total_defendants[pled_guilty]),
      pct_pled_guilty= num_pled_guilty / total_cases 
    )
  return(plea_rate_by_narco)
}

summarize_most_common <- function(df, to_group_by='OFFENSE.TYPE') {
  # Group by one field (defaulting to type of offense), then sort by # of defendants that fall in various levels of that field
  # The trailing `_` tip came from: https://stackoverflow.com/questions/21208801/group-by-multiple-columns-in-dplyr-using-string-vector-input
  summary_counts <- df %>%
    group_by_(to_group_by) %>%
    summarise(total_defendants=sum(DEFENDANT.COUNT)) %>%
    arrange(desc(total_defendants))
  
  with_cumulatives <- summary_counts %>%
    mutate(
      pct_total = total_defendants / sum(total_defendants),
      cumulative_num_defendants = cumsum(total_defendants),
      cumulative_pct_total = cumsum(pct_total)
    )
  
  return(with_cumulatives)
}

df <- read.csv('State_s_Attorney_Felony_Cases_-_Disposition_Outcomes_By_Offense_Type_and_Defendant_Race.csv')
just2016 <- df %>%
  filter(DISPOSITION != '') %>%
  filter(YEAR == '2016')

# There are 82 unique offense types - can we just limit to most common, say, 10?
print(length(unique(just2016$OFFENSE.TYPE)))
# This should basically match page 8 of the report. Numbers seem slightly off / different, but not
# significantly so
most_common <- summarize_most_common(just2016)

disagg <- prep_disaggregated()
narcotics_plea_rates(disagg)
# Dispositions
# FNPC -> "finding of no probable cause."
# FNG -> Finding not guilt
# Transferred - Misd Crt -> "Missed court?"
# BFW -> "A "bond forfeiture warrant," indicating the case cannot proceed because the
# defendant has failed to reappear for court.
