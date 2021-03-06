I [recently wrote a
post](http://nrjones8.me/cook-county-sao-dispositions.html) looking at
dispositions coming out of the Cook County State Attorney's Office (SAO)
- that post analyzed data that [the SAO recently
released](https://www.cookcountystatesattorney.org/news/cook-county-state-s-attorney-kim-foxx-announces-release-office-s-first-online-data-report)
on how they've handled cases since 2011. All of the analysis I did was
in R, and made heavy use of the
[`dplyr`](http://dplyr.tidyverse.org/index.html) library. While there
was a little bit of a learning curve at first, I found `dplyr` to be
*much* easier to use than other similar libraries in R.

This post explains my analysis showing the actual code used - it also
serves as a "hands on" introduction to the `dplyr` set of tools.

Preparing our data
------------------

The data analyzed below is made up of dispositions ("outcomes") of cases
handled by the SAO between 2011 and 2016. It's broken down by year,
disposition, offense type, race, and the total number of defendants -
e.g. one row would tell us that the SAO had 903 narcotics cases that
were pled guilty involving white defendants in 2015. The full dataset
can be accessed
[here](https://datacatalog.cookcountyil.gov/Courts/State-s-Attorney-Felony-Cases-Disposition-Outcomes/cqdb-r84f).

    df <- read.csv('State_s_Attorney_Felony_Cases_-_Disposition_Outcomes_By_Offense_Type_and_Defendant_Race.csv')
    kable(head(df))

<table>
<thead>
<tr class="header">
<th align="right">YEAR</th>
<th align="left">DISPOSITION</th>
<th align="left">OFFENSE.TYPE</th>
<th align="left">RACE</th>
<th align="right">DEFENDANT.COUNT</th>
</tr>
</thead>
<tbody>
<tr class="odd">
<td align="right">2011</td>
<td align="left"></td>
<td align="left">Aggravated Battery</td>
<td align="left">Black</td>
<td align="right">1</td>
</tr>
<tr class="even">
<td align="right">2011</td>
<td align="left"></td>
<td align="left">Aggravated Battery With A Firearm</td>
<td align="left">Black</td>
<td align="right">1</td>
</tr>
<tr class="odd">
<td align="right">2011</td>
<td align="left"></td>
<td align="left">Aggravated DUI</td>
<td align="left"></td>
<td align="right">2</td>
</tr>
<tr class="even">
<td align="right">2011</td>
<td align="left"></td>
<td align="left">Aggravated DUI</td>
<td align="left">Black</td>
<td align="right">2</td>
</tr>
<tr class="odd">
<td align="right">2011</td>
<td align="left"></td>
<td align="left">Aggravated DUI</td>
<td align="left">White [Hispanic or Latino]</td>
<td align="right">2</td>
</tr>
<tr class="even">
<td align="right">2011</td>
<td align="left"></td>
<td align="left">Aggravated Fleeing and Eluding</td>
<td align="left">Black</td>
<td align="right">1</td>
</tr>
</tbody>
</table>

    unique_dispositions <- unique(df$DISPOSITION)
    length(unique_dispositions)

    ## [1] 33

    unique_dispositions[grepl('^Plea', unique_dispositions)]

    ## [1] Plea Of Guilty                   Plea of Guilty - Amended Charge 
    ## [3] Plea of Guilty - Lesser Included Plea of Guilty But Mentally Ill 
    ## 33 Levels:  BFW Case Dismissed Charge Rejected ... WOWI

As you can see from the first few rows of the table, we are working with
aggregated counts of offenses, by year, offense type, disposition, and
race. There are 33 different dispositions, some of which are very
similar. Let's do a little preprocessing on the data to make it easier
to work with. For our use case here, we're mostly interested in
dispositions based on the particular offense type.

    prep_disaggregated <- function(df) {
      df <- df %>%
        # Exclude blank dispositions, there are a few
        filter(DISPOSITION != '') %>%
        # Keep year, disposition, and offense type
        group_by(YEAR, DISPOSITION, OFFENSE.TYPE) %>%
        # Sum up the total number of defendants
        summarise(total_defendants=sum(DEFENDANT.COUNT)) %>%
        # Add an extra column to determine whether the particular disposition was a guilty plea. There
        # are 4 different dispositions for guilty pleas, which we can identify with the '^Plea' regular
        # expression
        mutate(
          pled_guilty = grepl('^Plea', DISPOSITION)
        )

      return(df)
    }
    disagg <- prep_disaggregated(df)
    kable(head(disagg))

<table>
<thead>
<tr class="header">
<th align="right">YEAR</th>
<th align="left">DISPOSITION</th>
<th align="left">OFFENSE.TYPE</th>
<th align="right">total_defendants</th>
<th align="left">pled_guilty</th>
</tr>
</thead>
<tbody>
<tr class="odd">
<td align="right">2011</td>
<td align="left">BFW</td>
<td align="left">Aggravated Battery</td>
<td align="right">1</td>
<td align="left">FALSE</td>
</tr>
<tr class="even">
<td align="right">2011</td>
<td align="left">BFW</td>
<td align="left">Aggravated DUI</td>
<td align="right">20</td>
<td align="left">FALSE</td>
</tr>
<tr class="odd">
<td align="right">2011</td>
<td align="left">BFW</td>
<td align="left">Driving With Suspended Or Revoked License</td>
<td align="right">3</td>
<td align="left">FALSE</td>
</tr>
<tr class="even">
<td align="right">2011</td>
<td align="left">BFW</td>
<td align="left">DUI</td>
<td align="right">3</td>
<td align="left">FALSE</td>
</tr>
<tr class="odd">
<td align="right">2011</td>
<td align="left">BFW</td>
<td align="left">Identity Theft</td>
<td align="right">1</td>
<td align="left">FALSE</td>
</tr>
<tr class="even">
<td align="right">2011</td>
<td align="left">BFW</td>
<td align="left">Narcotics</td>
<td align="right">8</td>
<td align="left">FALSE</td>
</tr>
</tbody>
</table>

`mutate`, `group_by`, `summarise` - getting answers out of our data
-------------------------------------------------------------------

Now that we have our data prepared, we can start looking at the first
question of interest: how often are plea bargains used in narcotics
cases vs. other cases? The dplyr library makes this kind of analysis
much easier. The below snippet uses a number of the library's features
to group the data by narcotics vs. non-narcotics, sum the total number
of cases of each, and break down the number of each case type by the %
of such cases that were pled guilty. There are comments in-line as well.

    narcotics_vs_other_plea_rates <- function(df) {
      # Expects to have a "pled_guilty" column already present
      plea_rate_by_narco <- df %>%
        # Add a boolean column to indicate whether the offense was a narcotics cases or not
        mutate(narcotics_case = OFFENSE.TYPE == 'Narcotics') %>%
        # Now group by that new column - dplyr is flexible enough to use "new" column in expressions that
        # follow
        group_by(narcotics_case) %>%
        # Now that we're grouping by the `narcotics_case` boolean, sum up the total number of cases, the number
        # of cases that were pled guilt (as indicated by the `pled_guilty` field), the the percentage of cases
        # pled guilty. Note that columns used in `summarise` can reference one another - e.g. pct_pled_guilty
        # is a function of two other columns in that same `summarise` invocation.
        summarise(
          total_cases = sum(total_defendants),
          num_pled_guilty = sum(total_defendants[pled_guilty]),
          pct_pled_guilty= num_pled_guilty / total_cases
        )
      return(plea_rate_by_narco)
    }
    plea_rates_by_narco <- narcotics_vs_other_plea_rates(disagg)
    kable(plea_rates_by_narco)

<table>
<thead>
<tr class="header">
<th align="left">narcotics_case</th>
<th align="right">total_cases</th>
<th align="right">num_pled_guilty</th>
<th align="right">pct_pled_guilty</th>
</tr>
</thead>
<tbody>
<tr class="odd">
<td align="left">FALSE</td>
<td align="right">125918</td>
<td align="right">95295</td>
<td align="right">0.7568020</td>
</tr>
<tr class="even">
<td align="left">TRUE</td>
<td align="right">101924</td>
<td align="right">43866</td>
<td align="right">0.4303795</td>
</tr>
</tbody>
</table>

Especially when you're new to `dplyr` (or any library), it's good to
double check your calculations. To double check that the summary above
makes sense, we can use some slightly simpler expressions to
hand-calculate the same numbers. As a library becomes more familiar,
these gut-checks may be less necessary.

    # Check total number of narcotics cases
    only_narcotics_cases <- disagg %>%
      filter(OFFENSE.TYPE == 'Narcotics')
    sum(only_narcotics_cases$total_defendants)

    ## [1] 101924

    # Check total number of _non_ narcotics cases
    non_narcotics_cases <- disagg %>%
      filter(OFFENSE.TYPE != 'Narcotics')
    sum(non_narcotics_cases$total_defendants)

    ## [1] 125918

    # Check total number of pled-out narcotics cases
    pled_out_narcotics_cases <- disagg %>%
      filter(OFFENSE.TYPE == 'Narcotics') %>%
      filter(pled_guilty)
    sum(pled_out_narcotics_cases$total_defendants)

    ## [1] 43866

    # Check total number of pled-out _non_ narcotics cases
    pled_out_non_narcotics_cases <- disagg %>%
      filter(OFFENSE.TYPE != 'Narcotics') %>%
      filter(pled_guilty)
    sum(pled_out_non_narcotics_cases$total_defendants)

    ## [1] 95295

`arrange` - why is the narcotics plea rate so low?
--------------------------------------------------

The vast majority of narcotics cases result in a guilty plea - see, e.g.
[this report from the Human Rights
Watch](https://www.hrw.org/report/2013/12/05/offer-you-cant-refuse/how-us-federal-prosecutors-force-drug-defendants-plead).
It focuses on federal drug cases, but the general trend of pleas holds
at the state level as well. The explanation for those high rates is
complicated, and I won't attempt to explain that here. But our analysis
above suggested that the plea rate was just 43% for narcotics cases,
which suggests that we're not interpreting the data correctly.

To investigate what's happening in general with narcotics cases, we'd
like to answer the question: what are the most common dispositions in
narcotics cases? What % of all cases do those dispositions represent?
`dplyr` can help us again here, this time using `arrange` to order our
data.

    most_common_dispos <- function(df) {
      num_all_dispos <- sum(df$total_defendants)
      most_common <- df %>%
        # We're interested in individual dispositions, so group by them here
        group_by(DISPOSITION) %>%
        # Add columns for the total number of cases per disposition, and the % of all cases
        summarise(
          total_dispos = sum(total_defendants),
          pct_of_total = total_dispos / num_all_dispos
        ) %>%
        # Arrange the rows by our newly added `total_dispos` column. Using `desc` orders the rows in descending
        # order, using the `total_dispos` column.
        arrange(desc(total_dispos))

      return(most_common)
    }
    most_common_narcotics_dispos <- most_common_dispos(only_narcotics_cases)
    kable(head(most_common_narcotics_dispos))

<table>
<thead>
<tr class="header">
<th align="left">DISPOSITION</th>
<th align="right">total_dispos</th>
<th align="right">pct_of_total</th>
</tr>
</thead>
<tbody>
<tr class="odd">
<td align="left">Plea Of Guilty</td>
<td align="right">43782</td>
<td align="right">0.4295554</td>
</tr>
<tr class="even">
<td align="left">FNPC</td>
<td align="right">26911</td>
<td align="right">0.2640301</td>
</tr>
<tr class="odd">
<td align="left">Nolle Prosecution</td>
<td align="right">26365</td>
<td align="right">0.2586731</td>
</tr>
<tr class="even">
<td align="left">Finding Guilty</td>
<td align="right">2045</td>
<td align="right">0.0200640</td>
</tr>
<tr class="odd">
<td align="left">FNG</td>
<td align="right">1735</td>
<td align="right">0.0170225</td>
</tr>
<tr class="even">
<td align="left">Death Suggested-Cause Abated</td>
<td align="right">184</td>
<td align="right">0.0018053</td>
</tr>
</tbody>
</table>

The above data show that a large percentage of narcotics cases are being
dismissed ("FNPC" means "finding of no probable cause" and "Nolle
Prosecution" simply means that the prosecution decided not to proceed).
I investigated why that was the case in a little bit more detail in
[THIS OTHER POST](link%20here), for those curious.

Conclusion
----------

As someone who hasn't worked with R for a few years, the introduction of
`dplyr` has made exploring data and running analyses much easier! I had
previously used [`plyr`](https://github.com/hadley/plyr) for similar use
cases, but found it difficult to read and understand. Aside from the
funny `%>%` syntax of `dplyr`, I find it much easier to read, write, and
understand.

I hope this was a helpful "tutorial" / introduction to `dplyr` -
suggestions, questions, and other feedback is welcome! Please reach out
via email or on [Twitter](https://twitter.com/nrjones8).
