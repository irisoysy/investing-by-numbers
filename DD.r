
############################################
##                                        ##
##         Investing by numbers           ##
##   a quantitative trading strategy by   ##
##         Mathieu Bouville, PhD          ##
##      <mathieu.bouville@gmail.com>      ##
##                                        ##
##       DD.r calculates drawdowns        ##
##                                        ##
############################################



## Loading DD list from csv file
loadDDlist <- function(otherAssetClasses=T, force=F) {
   if (!exists("DD") | force) {
      DD <<- read.csv("data/drawdownList.csv", col.names = c("startYear", "endYear", "comments"), stringsAsFactors=F, header=F)
      
      # removing the first 2 DD since they occur so early that CAPE-based strategies are unavailable at the time
      DD <<- DD[-1, ] 
      DD <<- DD[-1, ] 
      
      if(!otherAssetClasses) { # removing gold drawdowns
         DD <<- DD[-39, ]
         DD <<- DD[-39, ]
         DD <<- DD[-40, ] 
         DD <<- DD[-41, ] 
         #DD <<- DD[-50, ] turns out to be a bond DD as well
      }         
      
      numDD <<- dim(DD)[[1]]
      DD$dates <<- character(numDD)
      
      for (i in 1:numDD) { # creates names for drawdowns
         year1 <- floor(DD$startYear[i])
         year2 <- floor(DD$endYear[i] - .01) # 1999.00 means January 1999, i.e. the DD ended in 1998
         if (year1==year2) DD$dates[i] <<- as.character(year1) # single year DD displayed as "2000"
         else DD$dates[i] <<- paste0(year1, "-", year2)        #  multi-year DD displayed as "2000-2001"
      }
      calcDDinflationAll()
   }
}

## Calculate the drawdown (bigger price fall) for a certain startegy in a given date range
drawdown <- function(strategyName, startYear, endYear) {
   requireColInTR(strategyName)
   startIndex <- (startYear-def$dataStartYear)*12+1
   endIndex <- min((endYear-def$dataStartYear)*12, numData+1) # numData+1 b/c then we do endIndex-1
   
   if ( is.na( TR[startIndex, strategyName] ) )
      return(NA) # DD cannot be calculated
   else {
      DD <- 1
      highValue <- -1
      
      for (i in startIndex:(endIndex-1) ) 
         if ( !is.na(TR[i, strategyName]) ) {
            if (TR[i, strategyName] > highValue)  
               highValue <- TR[i, strategyName]
            else if (TR[i, strategyName] / highValue < DD)
               DD <- TR[i, strategyName] / highValue
         }   
      return(DD-1)
   }
}

# Adds values for all drawdowns to the DD data frame
CalcAllDrawdowns <- function(strategyName, force=F) {
   if ( !(strategyName %in% colnames(DD)) | force) {# if data do not exist yet or we force recalculation:
      DD[, strategyName]  <<- numeric(numDD)      
      for (i in 1:numDD) {
         DD[i, strategyName] <<- drawdown(strategyName, DD$startYear[i], DD$endYear[i])
      }
   }
   for ( i in 1:length(is.na(DD[strategyName])) )
      if ( is.na(DD[i, strategyName]) ) {         # If first drawdowns cannot be computed b/c it is too early
         DD[i, strategyName] <<- DD[i, "stocks"]  #    we assume the worst, i.e. the drawdown of stocks
         if (strategyName!="gold" && strategyName!="UKhousePrice") # no drawdown can be calculated before the data begin
            warning("A drawdown for '", strategyName, "' had to be approximated.")
      }
}

# Displays drawdowns worse than the threshold
showMajorDrawdowns <- function(strategyName, threshold=-.2, na.rm=F, force=F) {
   threshold <- -abs(threshold) # threshould can be positive or negative
   if ( !(strategyName %in% colnames(DD)) | force) # if data do not exist yet or we force recalculation:
      CalcAllDrawdowns(strategyName, force=force)
   majorDD <- DD[, strategyName]
   majorDD <- majorDD[majorDD <= threshold]
   if (na.rm) majorDD <- majorDD[!is.na(DD)] # if na.rm is True then we remove NA from major DD list
   return(majorDD)
}

# Displays drawdowns of strategy when refStrategy lost more than threshold
showMajorDrawdownsWithReference <- function(strategyName, refStrategyName, threshold=-.2, na.rm=F, force=F) {
   threshold <- -abs(threshold) # threshould can be positive or negative

   if ( !(strategyName %in% colnames(DD)) | force) # if data do not exist yet or we force recalculation:
      CalcAllDrawdowns(strategyName, force=force)
   if ( !(refStrategyName %in% colnames(DD)) | force) # if data do not exist yet or we force recalculation:
      CalcAllDrawdowns(refStrategyName, force=force)

   majorDD <- DD[, strategyName]
   refDD <- DD[, refStrategyName]
   
   if (na.rm) # if na.rm is True then we remove NA from major DD list of refStrategy, not strategy
      return(majorDD[(refDD <= threshold) & (!is.na(refDD))])
   else return(majorDD[refDD <= threshold])
}

# Displays drawdowns by their magnitude rather than chronologically
showWorstDrawdowns <- function(strategyName, threshold=0, na.rm=F, force=F) {
   # threshold=0 means that by default we display all DD in order of their magnitude
   worstDD <- showMajorDrawdowns(strategyName, threshold=threshold, na.rm=na.rm, force=force)
   return(worstDD[order(worstDD)])
}

# Displays drawdowns when refStrategy lost more than threshold (by their magnitude rather than chronologically)
showWorstDrawdownsWithReference <- function(strategyName, refStrategyName, threshold=0, na.rm=F, force=F) {
   # Calculates drawdowns of strategy when refStrategy lost the most
   worstDD <- showMajorDrawdownsWithReference(strategyName, refStrategyName, threshold=threshold, force=force)
   refDD <- showMajorDrawdowns(refStrategyName, threshold=threshold, force=force)
   if (na.rm) refDD <- refDD[!is.na(refDD)] # if na.rm is True then we remove NA from major DD list of refStrategy, not strategy
   return(worstDD[order(refDD)])
}

plotDD <- function(DDindex, padding=0, minTR=.8, maxTR=1.5, newStartYear="", newEndYear="", 
                   stratName1=def$typicalStrategies[[1]], stratName2=def$typicalStrategies[[2]], 
                   stratName3=def$typicalStrategies[[3]], stratName4=def$typicalStrategies[[4]]) {
   if (newStartYear == "") 
      newStartYear <- DD$startYear[DDindex]
   else if (newStartYear < 1000) # obviously not a year
      newStartYear <- DD$startYear[DDindex] + newStartYear
   if (newEndYear == "") 
      newEndYear   <- DD$endYear[DDindex]
   else if (newEndYear < 1000) # obviously not a year either
      newEndYear <- DD$endYear[DDindex] + newEndYear
      
   print( paste0(DD$dates[DDindex], ": nominally from ", DD$startYear[DDindex], " to ", DD$endYear[DDindex],
                 " -- plotted from ", newStartYear-padding, " to ", newEndYear+padding, 
                 " -- calculations from ", newStartYear, " to ", newEndYear) )

   plotReturnAndAlloc(stratName1=stratName1, stratName2=stratName2, stratName3=stratName3, stratName4=stratName4, 
              startYear = newStartYear - padding, 
              endYear   = newEndYear   + padding, 
              minTR=minTR, maxTR=maxTR)
   
   sapply(c(stratName1, stratName2, stratName3, stratName4), 
          function(x) round(drawdown(x, newStartYear, newEndYear)*100,1) )
}

# Displays the inflation during a certain drawdown event 
#   (useful to tell how much of the real drawdown was due to inflation)
showDDinflation <- function(DDindex) {
   return ( dat$CPI[(DD$endYear[DDindex]-def$dataStartYear)*12+1] / dat$CPI[(DD$startYear[DDindex]-def$dataStartYear)*12+1] - 1)
}

# Calculates the inflation during all drawdown events 
#   (useful to tell how much of the real drawdown was due to inflation)
calcDDinflationAll <- function() {
   DD$inflation <<- numeric(numDD)
   for (i in 1:numDD) 
      DD$inflation[i] <<- showDDinflation(i)
}
