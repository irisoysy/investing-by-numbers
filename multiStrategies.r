## Calculating average alloc between 2 strategies, and corresponding results
calcMultiStrategyNorm <- function(inputStrategyName1, inputStrategyName2, inputStrategyName3, inputStrategyName4, 
                                    fraction1, fraction2, fraction3, fraction4, 
                                    strategyName, delta="", force=F) {
   
   sumCoeff <- fraction1 + fraction2 + fraction3 + fraction4
   if (abs(sumCoeff-1)>1e-6) stop(paste("Sum of coefficients must be 1, not", sumCoeff))   

   requireColInNormalized(inputStrategyName1)
   requireColInNormalized(inputStrategyName2)
   if (!(inputStrategyName3 %in% colnames(normalized)) & fraction3 != 0) 
      stop(paste0("normalized$", inputStrategyName3, " does not exist."))
   if (!(inputStrategyName4 %in% colnames(normalized)) & fraction4 != 0) 
      stop(paste0("normalized$", inputStrategyName4, " does not exist."))
   
   if (!(strategyName %in% colnames(normalized)) | force) { # if data do not exist yet or we force recalculation:   
      addNumColToNormalized(strategyName)
      
      if(fraction4==0) {
         if(fraction3==0) 
            normalized[, strategyName] <<- fraction1*normalized[, inputStrategyName1] + fraction2*normalized[, inputStrategyName2]
         else          normalized[, strategyName] <<- fraction1*normalized[, inputStrategyName1] + 
            fraction2*normalized[, inputStrategyName2] + fraction3*normalized[, inputStrategyName3]
      }
      else normalized[, strategyName] <<- fraction1*normalized[, inputStrategyName1] + fraction2*normalized[, inputStrategyName2] + 
         fraction3*alloc[, inputStrategyName3] + fraction4*alloc[, inputStrategyName4] 
   }
}

   
createMultiStrategy <- function(inputStrategyName1, inputStrategyName2, inputStrategyName3, inputStrategyName4, 
                                fraction1=25, fraction2=25, fraction3=25, fraction4="", 
                                medianAlloc=def$medianAlloc, interQuartileAlloc=def$interQuartileAlloc, 
                                strategyName="", subtype, delta="", futureYears=def$futureYears, force=F) {
   
   if (!is.numeric(fraction1)) fraction1 <- 100 - fraction2 - fraction3 - fraction4
   if (!is.numeric(fraction2)) fraction2 <- 100 - fraction1 - fraction3 - fraction4
   if (!is.numeric(fraction3)) fraction3 <- 100 - fraction1 - fraction2 - fraction4
   if (!is.numeric(fraction4)) fraction4 <- 100 - fraction1 - fraction2 - fraction3
   sumCoeff <- fraction1 + fraction2 + fraction3 + fraction4
   if (abs(sumCoeff-100)>1e-6) stop(paste("Sum of coefficients must be 100, not", sumCoeff))
   
   if(strategyName=="") {
      if(fraction4==0) {
         if(fraction3==0)
            strategyName <- paste0(subtype, fraction1, "_", fraction2, "_", medianAlloc, "_", interQuartileAlloc)
         else strategyName <- paste0(subtype, fraction1, "_", fraction2, "_", fraction3, 
                                     "_", medianAlloc, "_", interQuartileAlloc)
      }
      else strategyName <- paste0(subtype, fraction1, "_", fraction2, "_", fraction3, "_", fraction4, 
                                  "_", medianAlloc, "_", interQuartileAlloc)
   }
  
   calcMultiStrategyNorm(inputStrategyName1=inputStrategyName1, inputStrategyName2=inputStrategyName2, 
                         inputStrategyName3=inputStrategyName3, inputStrategyName4=inputStrategyName4, 
                         fraction1=fraction1/100, fraction2=fraction2/100, fraction3=fraction3/100, fraction4=fraction4/100,
                         strategyName=strategyName, delta=delta, force=force)
   calcAllocFromNorm(strategyName, medianAlloc=medianAlloc, interQuartileAlloc=interQuartileAlloc)
   
   startIndex <- max( parameters$startIndex[ which(parameters$strategy == inputStrategyName1) ],
                      parameters$startIndex[ which(parameters$strategy == inputStrategyName2) ],
                      parameters$startIndex[ which(parameters$strategy == inputStrategyName3) ],
                      parameters$startIndex[ which(parameters$strategy == inputStrategyName4) ] )
 
   if (!(strategyName %in% colnames(TR)) | force) { # if data do not exist yet or we force recalculation:   
      addNumColToTR(strategyName)
      calcStrategyReturn(strategyName, startIndex)
   }
   
   if ( !(strategyName %in% parameters$strategy) | force) {
      if ( !(strategyName %in% parameters$strategy) ) {
         parameters[nrow(parameters)+1, ] <<- NA
         parameters$strategy[nrow(parameters)] <<- strategyName
      }
      index <- which(parameters$strategy == strategyName)
      
      parameters$strategy[index] <<- strategyName
      parameters$type[index] <<- "multi"
      parameters$subtype[index] <<- subtype
      parameters$startIndex[index] <<- startIndex
      parameters$medianAlloc[index] <<-  medianAlloc
      parameters$interQuartileAlloc[index] <<-  interQuartileAlloc
      
      parameters$inputStrategyName1[index] <<- inputStrategyName1
      parameters$fraction1[index] <<- fraction1
      parameters$inputStrategyName2[index] <<- inputStrategyName2
      parameters$fraction2[index] <<- fraction2
      parameters$inputStrategyName3[index] <<- inputStrategyName3
      parameters$fraction3[index] <<- fraction3
      if (fraction4 > 0) {
      parameters$inputStrategyName4[index] <<- inputStrategyName4
      parameters$fraction4[index] <<- fraction4
      }
   }
   calcStatisticsForStrategy(strategyName=strategyName, futureYears=futureYears, force=force)
   stats$type[which(stats$strategy == strategyName)] <<- parameters$type[which(parameters$strategy == strategyName)]
   stats$subtype[which(stats$strategy == strategyName)] <<- parameters$subtype[which(parameters$strategy == strategyName)]
}
   

searchForOptimalMultiSerial <- function(inputStrategyName1, inputStrategyName2, inputStrategyName3, inputStrategyName4, 
                                  minF1=50L, maxF1=70L, byF1=10L, minF2=0L, maxF2=40L, byF2=10L, 
                                  minF3=10L, maxF3=30L, byF3=10L, minF4=0L, maxF4=0L, 
                                  minMed=80, maxMed=95, byMed=5, minIQ=30, maxIQ=60, byIQ=10, 
                                  futureYears=def$futureYears, tradingCost=def$tradingCost, subtype,
                                  minTR=6, maxVol=14.5, maxDD2=2.2, minTO=0., force=F) {
   
   print(paste0("strategy                |  TR  |", futureYears, " yrs: med, 5%| vol.  |alloc: avg, now|TO yrs| DD^2 | score  ") )
   for(f1 in seq(minF1, maxF1, by=byF1)) {
      for(f2 in seq(minF2, maxF2, by=byF2)) 
         for(f3 in seq(minF3, maxF3, by=byF3)) {
            f4 <- round(100 - f1 - f2 - f3)
            if ((f4 >= minF4) & (f4 <= maxF4)) 
               for ( med in seq(minMed, maxMed, by=byMed) )       
                  for ( IQ in seq(minIQ, maxIQ, by=byIQ) ) {
                     if (maxF3 > 0)
                        strategyName = paste0(subtype, f1, "_", f2, "_", f3, "_", med, "_", IQ)
                     else strategyName = paste0(subtype, f1, "_", f2, "_", med, "_", IQ)
                     #print(strategyName)
                     createMultiStrategy(inputStrategyName1, inputStrategyName2, inputStrategyName3, inputStrategyName4, 
                                         f1, f2, f3, f4, medianAlloc=med, interQuartileAlloc=IQ, 
                                         strategyName=strategyName, delta="", subtype=subtype, force=force)
                     
                     showSummaryForStrategy(strategyName, futureYears=futureYears, tradingCost=tradingCost, 
                                            minTR=minTR, maxVol=maxVol, maxDD2=maxDD2, minTO=minTO, force=F)
                  }
         }
      plotReturnVsFour()
   }
   #    showSummaries(futureYears=futureYears, tradingCost=tradingCost, detailed=F, force=F)
}


# Parallel search for optimal parameters
searchForOptimalMultiParallel <- function(inputStrategyName1, inputStrategyName2, inputStrategyName3, inputStrategyName4, 
                                      minF1=50L, maxF1=70L, byF1=5L, minF2=0L, maxF2=40L, byF2=5L, 
                                      minF3=10L, maxF3=30L, byF3=5L, minF4=0L, maxF4=0L, 
                                      minMed=80, maxMed=95, byMed=5, minIQ=30, maxIQ=60, byIQ=10, 
                                      futureYears=def$futureYears, tradingCost=def$tradingCost, subtype,
                                      minTR=6, maxVol=14.5, maxDD2=2.2, minTO=0., force=F) {
   
   wrapper <- function(IQ) {
      if (maxF3 > 0)
         strategyName = paste0(subtype, f1, "_", f2, "_", f3, "_", med, "_", IQ)
      else strategyName = paste0(subtype, f1, "_", f2, "_", med, "_", IQ)
      #print(strategyName)
      createMultiStrategy(inputStrategyName1, inputStrategyName2, inputStrategyName3, inputStrategyName4, 
                          f1, f2, f3, f4, medianAlloc=med, interQuartileAlloc=IQ, 
                          strategyName=strategyName, delta="", subtype=subtype, force=force)     
#          showSummaryForStrategy(strategyName, futureYears=futureYears, tradingCost=tradingCost, 
#                                 minTR=minTR, maxVol=maxVol, maxDD2=maxDD2, minTO=minTO, force=F)
   }
   
   if (def$CPUnumber == 1)
      print(paste0("strategy                |  TR  |", futureYears, " yrs: med, 5%| vol.  |alloc: avg, now|TO yrs| DD^2 | score  ") )
   for(f1 in seq(minF1, maxF1, by=byF1)) {
      for(f2 in seq(minF2, maxF2, by=byF2)) 
         for(f3 in seq(minF3, maxF3, by=byF3)) {
            f4 <- round(100 - f1 - f2 - f3)
            if ((f4 >= minF4) & (f4 <= maxF4)) 
               for ( med in seq(minMed, maxMed, by=byMed) )       
                  sfClusterApplyLB( seq(minIQ, maxIQ, by=byIQ) , wrapper )
         }
      plotReturnVsFour()
   }
   #    showSummaries(futureYears=futureYears, tradingCost=tradingCost, detailed=F, force=F)
}



searchForOptimalMulti <- function(inputStrategyName1, inputStrategyName2, inputStrategyName3, inputStrategyName4, 
                                           minF1=50L, maxF1=70L, byF1=5L, minF2=0L, maxF2=40L, byF2=5L, 
                                           minF3=10L, maxF3=30L, byF3=5L, minF4=0L, maxF4=0L, 
                                           minMed=80, maxMed=95, byMed=5, minIQ=30, maxIQ=60, byIQ=10, 
                                           futureYears=def$futureYears, tradingCost=def$tradingCost, subtype,
                                           minTR=6, maxVol=14.5, maxDD2=2.2, minTO=0., CPUnumber=def$CPUnumber, force=F) {
   
   if (CPUnumber > 1) {
      library(snowfall)
      sfInit( parallel=TRUE, cpus=CPUnumber )
      sfExportAll( )
            
      searchForOptimalMultiParallel(inputStrategyName1, inputStrategyName2, inputStrategyName3, inputStrategyName4, 
                                    minF1, maxF1, byF1, minF2, maxF2, byF2, 
                                    minF3, maxF3, byF3, minF4, maxF4, 
                                    minMed, maxMed, byMed, minIQ, maxIQ, byIQ, 
                                    futureYears=futureYears, tradingCost=tradingCost, subtype,
                                    minTR, maxVol, maxDD2, minTO, force=force) 
      sfStop()   
   } else
      searchForOptimalMultiSerial(inputStrategyName1, inputStrategyName2, inputStrategyName3, inputStrategyName4, 
                                  minF1, maxF1, byF1, minF2, maxF2, byF2, 
                                  minF3, maxF3, byF3, minF4, maxF4, 
                                  minMed, maxMed, byMed, minIQ, maxIQ, byIQ, 
                                  futureYears=futureYears, tradingCost=tradingCost, subtype,
                                  minTR, maxVol, maxDD2, minTO, force=force)   
}



searchForOptimalValue <- function(inputStrategyName1=def$typicalCAPE, inputStrategyName2=def$typicalDetrended, 
                                  inputStrategyName3="", inputStrategyName4="", 
                                  minF1=60L, maxF1=90L, byF1=5L, minF2=15L, maxF2=35L, byF2=5L, 
                                  minF3=0L, maxF3=0L, byF3=0L, minF4=0L, maxF4=0L, 
                                  minMed=80, maxMed=90, byMed=5, minIQ=90, maxIQ=98, byIQ=2, 
                                  futureYears=def$futureYears, tradingCost=def$tradingCost, subtype="value",
                                  minTR=7.1, maxVol=14.1, maxDD2=1.6, minTO=8, CPUnumber=def$CPUnumber, force=F) {
   searchForOptimalMulti(inputStrategyName1=inputStrategyName1, inputStrategyName2=inputStrategyName2,
                         inputStrategyName3=inputStrategyName3, inputStrategyName4=inputStrategyName4, 
                         minF1=minF1, maxF1=maxF1, byF1=byF1, minF2=minF2, maxF2=maxF2, byF2=byF2, 
                         minF3=minF3, maxF3=maxF3, byF3=byF3, minF4=minF4, maxF4=maxF4, 
                         minMed=minMed, maxMed=maxMed, byMed=byMed, minIQ=minIQ, maxIQ=maxIQ, byIQ=byIQ, 
                         futureYears=futureYears, tradingCost=tradingCost, subtype=subtype,
                         minTR=minTR, maxVol=maxVol, maxDD2=maxDD2, minTO=minTO, CPUnumber=CPUnumber, force=force) 
   print("")
   showSummaryForStrategy(def$typicalValue)
}


searchForOptimalTechnical <- function(inputStrategyName1=def$typicalSMA, inputStrategyName2=def$typicalBoll, 
                                      inputStrategyName3=def$typicalMomentum, inputStrategyName4="", 
                                      minF1=40L, maxF1=80L, byF1=5L, minF2=20L, maxF2=30L, byF2=5L, 
                                      minF3=20L, maxF3=30L, byF3=5L, minF4=0L, maxF4=0L, 
                                      minMed=90, maxMed=95, byMed=5, minIQ=30, maxIQ=60, byIQ=10, 
                                      futureYears=def$futureYears, tradingCost=def$tradingCost, subtype="technical",
                                      minTR=6.8, maxVol=14.5, maxDD2=1.8, minTO=1.2, CPUnumber=def$CPUnumber, force=F) {
   searchForOptimalMulti(inputStrategyName1=inputStrategyName1, inputStrategyName2=inputStrategyName2,
                         inputStrategyName3=inputStrategyName3, inputStrategyName4=inputStrategyName4, 
                         minF1=minF1, maxF1=maxF1, byF1=byF1, minF2=minF2, maxF2=maxF2, byF2=byF2, 
                         minF3=minF3, maxF3=maxF3, byF3=byF3, minF4=minF4, maxF4=maxF4, 
                         minMed=minMed, maxMed=maxMed, byMed=byMed, minIQ=minIQ, maxIQ=maxIQ, byIQ=byIQ, 
                         futureYears=futureYears, tradingCost=tradingCost, subtype=subtype,
                         minTR=minTR, maxVol=maxVol, maxDD2=maxDD2, minTO=minTO, CPUnumber=CPUnumber, force=force) 
   print("")
   showSummaryForStrategy(def$typicalTechnical)
}


searchForOptimalBalanced <- function(inputStrategyName1=def$typicalValue, inputStrategyName2=def$typicalTechnical, 
                            inputStrategyName3="", inputStrategyName4="", 
                            minF1=75L, maxF1=100L, byF1=5L, minF2=10L, maxF2=100L, byF2=5L, 
                            minF3=0L, maxF3=0L, byF3=0L, minF4=0L, maxF4=0L, 
                            minMed=98, maxMed=98, byMed=2, minIQ=70, maxIQ=90, byIQ=10, 
                            futureYears=def$futureYears, tradingCost=def$tradingCost, subtype="balanced", 
                            minTR=7.7, maxVol=14.8, maxDD2=2., minTO=2.5, CPUnumber=def$CPUnumber, force=F) {
   totTime <- proc.time()
    
   searchForOptimalMulti(inputStrategyName1=inputStrategyName1, inputStrategyName2=inputStrategyName2,
                         inputStrategyName3=inputStrategyName3, inputStrategyName4=inputStrategyName4, 
                         minF1=minF1, maxF1=maxF1, byF1=byF1, minF2=minF2, maxF2=maxF2, byF2=byF2, 
                         minF3=minF3, maxF3=maxF3, byF3=byF3, minF4=minF4, maxF4=maxF4, 
                         minMed=minMed, maxMed=maxMed, byMed=byMed, minIQ=minIQ, maxIQ=maxIQ, byIQ=byIQ, 
                         futureYears=futureYears, tradingCost=tradingCost, subtype=subtype,
                         minTR=minTR, maxVol=maxVol, maxDD2=maxDD2, minTO=minTO, CPUnumber=CPUnumber, force=force) 
   print("")
   showSummaryForStrategy(def$typicalBalanced)
   
   print( paste("time for searchForOptimalBalanced():", round(summary(proc.time())[[3]] - totTime[[3]] , 2) ) )
   
}
