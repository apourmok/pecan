#--------------------------------------------------------------------------------------------------#
##' Returns list of ensemble output
##'
##' @name read.ensemble.output
##' @title Read Ensemble Output
##' @return list of ensemble output 
##' @export
##'
read.ensemble.output <- function(ensemble.size, host, outdir, pft.name='', read.output = read.output.ed){
  ensemble.output <- list()
  rsync(paste(host$name, ':', host$outdir, 
              '*', get.run.id('ENS', '', pft.name=pft.name), '*', sep=''),
        outdir)
  for(ensemble.id in seq(ensemble.size)) {
    run.id <- get.run.id('ENS', left.pad.zeros(ensemble.id, 5), pft.name=pft.name)#log10(ensemble.size)+1))
    ensemble.output[[ensemble.id]] <- read.output(run.id, outdir)
  }
  return(ensemble.output)
}
#==================================================================================================#


#--------------------------------------------------------------------------------------------------#
##' Read output from sensitivity runs
##' 
##' @name read.sa.output
##' @title Read SA output
##' @return dataframe with one col per quantile analysed and one row per trait,
##'  each cell is a list of model output over time
##' @export
##'
read.sa.output <- function(traits, quantiles, host, outdir, pft.name='', read.output = read.output.ed){
  sa.output <- data.frame()
  rsync(paste(host$name, ':', host$outdir, 
              '*', get.run.id('SA', '', pft.name=pft.name), '*', sep=''),
        outdir)
  for(trait in traits){
    for(quantile in quantiles){
      run.id <- get.run.id('SA', round(quantile,3), trait=trait, pft.name=pft.name)
      sa.output[as.character(round(quantile*100,3)), trait] <- read.output(run.id, outdir)
    }
  }
  sa.output['50',] <- read.output(get.run.id('SA', 'median'), outdir)
  return(sa.output)
}
#==================================================================================================#


####################################################################################################
### EOF.  End of R script file.            	
####################################################################################################