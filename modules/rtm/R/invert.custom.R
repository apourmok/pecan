#' @name invert.custom
#' @title Bayesian inversion of a model
#' @details Performs an inversion of an arbitrary model using a modified 
#' Metropolis Hastings algorithm with block sampling. This may be slightly 
#' slower than the implementation in Fortran, but is much more customizable, as 
#' the model can be any R function.
#' @param observed Vector, matrix, or data frame (coerced to matrix) of 
#' observed values. For spectral data, wavelengths are rows and spectra are 
#' columns.
#' @param settings R list object containing the following elements:
#' 
#' inits Vector of initial values of model parameters to be inverted.
#'
#' ngibbs Number of MCMC iterations
#'
#' prior.function Function for use as prior. Should take a vector of parameters 
#' as input and return a single value -- the sum of their log-densities -- as 
#' output.
#'
#' param.mins Vector of minimum values for inversion parameters

#' model The model to be inverted. This should be an R function that takes 
#' `params` as input and returns one column of `observed` (nrows should be the 
#' same). Constants should be implicitly included here.
#'
#' adapt Number of steps for adapting covariance matrix (i.e. adapt every 'n' 
#' steps). Default=100
#' adj_min Minimum threshold for rescaling Jump standard deviation.  Default = 
#' 0.1.
#' 
#' target Target acceptance rate. Default=0.234, based on recommendation for 
#' multivariate block sampling in Haario et al. 2001
#' 
#' do.lsq Perform least squares optimization first (see `invert.lsq`), and use 
#' outputs to initialize Metropolis Hastings. This may improve mixing time, but 
#' risks getting caught in a local minimum.  Default=FALSE
#' @param quiet Do not show progress bar. Default=FALSE
invert.custom <- function(observed, settings, quiet=FALSE){
    observed <- as.matrix(observed)
    nspec <- ncol(observed)
    nwl <- nrow(observed)

    need.settings <- c("inits", "ngibbs", "prior.function", "param.mins", "adapt", 
                       "adj_min", "target", "do.lsq", "model")
    have.settings <- names(settings)
    overlap.settings <- need.settings %in% have.settings
    if(any(!overlap.settings)){
        error.msg <- paste("Missing the following settings:",
                        paste(need.settings[!overlap.settings], collapse=" "),
                        "Try modifying a default.settings() object",
                        sep = "\n")
        stop(error.msg)
    }

# Unpack settings list
    model <- settings$model
    inits <- settings$inits
    ngibbs <- settings$ngibbs
    prior.function <- settings$prior.function
    param.mins <- settings$param.mins
    adapt <- settings$adapt
    adj_min <- settings$adj_min
    target <- settings$target
    do.lsq <- settings$do.lsq

# Set up inversion
    npars <- length(inits)
    if(do.lsq){
        fit <- invert.lsq(observed, inits, model, lower=param.mins)
        inits <- fit$par
    }
    rp1 <- 0.001 + nspec*nwl/2
    rsd <- 0.5
    PrevSpec <- model(inits)
    PrevError <- PrevSpec - observed
    initsd <- inits * 0.05
    Jump <- diag(initsd)
    results <- matrix(NA, nrow=ngibbs, ncol=npars+1)
    if(!is.null(names(inits))) cnames <- names(inits)
    else cnames <- sprintf("par%d", 1:length(inits))
    colnames(results) <- c(cnames, "residual")
    ar <- 0
    if(!quiet) pb <- txtProgressBar(min=0, max=ngibbs, style=3)
    for(ng in 1:ngibbs){
        if(!quiet) setTxtProgressBar(pb, ng)
        if(ng %% adapt < 1){
            if(ar < 2){
                rescale <- diag(rep(adj_min,npars))
                Jump <- rescale %*% Jump %*% rescale
            } else{
                adj <- max(ar / adapt / target, adj_min)
                region <- seq(ng-adapt, ng-1)
                stdev <- apply(results[region,1:npars], 2, sd)
                rescale <- diag(stdev * adj)
                cormat <- cor(results[region,1:npars])
                if(any(is.na(cormat))) cormat <- diag(rep(1,4))
                Jump <- rescale %*% cormat %*% rescale
            }
            ar <- 0
        }
        tvec <- mvrnorm(1, inits, Jump)
        if(all(tvec > param.mins)){
            TrySpec <- model(tvec)
            TryError <- TrySpec - observed
            TryPost <- sum(dnorm(TryError,0,rsd,1)) + prior.function(tvec)
            PrevPost <- sum(dnorm(PrevError,0,rsd,1)) + prior.function(inits)
            a <- exp(TryPost - PrevPost)
            if(is.na(a)) a <- -1
            if(a > runif(1)){
                inits <- tvec
                PrevError <- TryError
                ar <- ar + 1
            }
        }
        results[ng,1:npars] <- inits
        rp2 <- 0.001 + sum(PrevError * PrevError)/2
        rinv <- rgamma(1, rp1, rp2)
        rsd <- 1/sqrt(rinv)
        results[ng,npars+1] <- rsd
    }
    close(pb)
    return(results)
}

