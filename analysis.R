library(dplyr)
library(ggplot2)

# Dispositions
# FNPC -> "finding of no probable cause."
# FNG -> Finding not guilt
# Transferred - Misd Crt -> "Missed court?"
# BFW -> "A "bond forfeiture warrant," indicating the case cannot proceed because the
# defendant has failed to reappear for court.

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
      pled_guilty = grepl('^Plea', DISPOSITION)
    )
  
  return(df)
}

plea_rates <- function(df) {
  # "Nolle Prosecution" (SAO chose not to proceed)
  # "FNPC" (Finding of no probable cause)
  # Both of these _kind of_ mean "the cases was dismissed"
  not_dismissed <- df %>%
    filter(!DISPOSITION %in% c('Nolle Prosecution', 'FNPC'))
  
  not_dismissed_yearly_narco_summary <- not_dismissed %>%
    group_by(YEAR) %>%
    summarise(
      total_cases = sum(total_defendants),
      pled_guilty = sum(total_defendants[pled_guilty]),
      pct_pled = pled_guilty / total_cases
    )
  return(not_dismissed_yearly_narco_summary)
}

#' Answers the question: how often do narcotics cases end in a guilty plea, vs. other 
#' types of cases?
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

#' Answers the question: what are the most common dispositions for the cases in the provided
#' data frame?
most_common_dispos <- function(df) {
  num_all_dispos <- sum(df$total_defendants)
  most_common <- df %>%
    group_by(DISPOSITION) %>%
    summarise(
      total_dispos = sum(total_defendants),
      pct_of_total = total_dispos / num_all_dispos
    ) %>%
    arrange(desc(total_dispos))
  
  return(most_common)
}

plot_narco_dispos_over_time <- function(df, dispositions_to_include) {
  # There are quite a few dispositions, most of which don't include very many cases. So let's only
  # plot a subset of those dispositions, which are passed in as a parameter
  only_most_common <- df %>%
    filter(DISPOSITION %in% dispositions_to_include)
  g <- ggplot(only_most_common, aes(x=YEAR, y=total_defendants, fill=DISPOSITION)) +
    geom_area() +
    scale_fill_brewer() +
    scale_x_continuous('Year') +
    scale_y_continuous('Total Number of Cases') +
    ggtitle('Cook County Narcotics Cases - Most Common Dispositions') +
    theme(plot.title = element_text(hjust = 0.5))
  print(g)
}

#' Answers question: how has the total number of narcotics cases changed over time?
total_narcos_over_time <- function(df) {
  yearly <- df %>%
    group_by(YEAR) %>%
    summarise(total_cases=sum(total_defendants))
  return(yearly)
}

df <- read.csv('State_s_Attorney_Felony_Cases_-_Disposition_Outcomes_By_Offense_Type_and_Defendant_Race.csv')
disagg <- prep_disaggregated()

plea_rates_by_narco <- narcotics_vs_other_plea_rates(disagg)
print('Plea rates: narcotics vs. other types')
print(plea_rates_by_narco)
only_narcotics <- disagg %>%
  filter(OFFENSE.TYPE == 'Narcotics')

non_narcotics <- disagg %>%
  filter(OFFENSE.TYPE != 'Narcotics')

most_common_dispos_for_narcos <- most_common_dispos(only_narcotics)
most_common_dispos_for_non_narcos <- most_common_dispos(non_narcotics)

print('Narcotics cases: most common disposition')
print(head(most_common_dispos_for_narcos))

print('Non-narcotics cases: most common disposition')
print(head(most_common_dispos_for_non_narcos))

not_dismissed_yearly_narco_summary <- plea_rates(only_narcotics)
print('Narcotics cases - not dismissed, by whether they were pled guilty')
print(not_dismissed_yearly_narco_summary)

not_dismissed_yearly_non_narcotics_summary <- plea_rates(non_narcotics)
print('NON-narcotics cases - not dismissed, by whether they were pled guilty')
print(not_dismissed_yearly_non_narcotics_summary)

total_yearly_narco <- total_narcos_over_time(only_narcotics)

plot_narco_dispos_over_time(
  only_narcotics,
  head(most_common_dispos_for_narcos$DISPOSITION, 5)
)

plot_narco_dispos_over_time(
  non_narcotics %>% group_by(YEAR, DISPOSITION) %>% summarise(total_defendants=sum(total_defendants)),
  head(most_common_dispos_for_non_narcos$DISPOSITION, 5)
)