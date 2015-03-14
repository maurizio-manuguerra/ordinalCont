#' Print continuous ordinal regression objects
#'
#' This function prints an ocmm object 
#' @param x An object of class "ocm", usually, a result of a call to ocm.
#' @param ... Further arguments passed to or from other methods.
#' @keywords likelihood, log-likelihood.
#' @method print ocmm
#' @export

print.ocmm <- function(x, ...)
{
  cat("Call:\n")
  print(x$call)
  cat("\nCoefficients:\n")
  print(x$coefficients, ...)
}

#' @title Summarizing Continuous Ordinal Fits
#' @description summary method for class "ocm"
#' @param object An object of class "ocm", usually, a result of a call to ocm.
#' @param ... Further arguments passed to or from other methods.
#' @method summary ocmm
#' @keywords summary
#' @export

summary.ocmm <- function(object, ...)
{
  se <- sqrt(diag(object$vcov))
  tval <- coef(object)[1:length(se)] / se
  TAB <- cbind(Estimate = coef(object),
               StdErr = se,
               t.value = tval,
               p.value = 2*pt(-abs(tval), df=object$df))
  res <- list(call=object$call,
              coefficients=TAB)
  class(res) <- "summary.ocm"
  print(res, ...)
}

#' @title Summarizing Continuous Ordinal Fits
#' @description summary method for class "summary.ocm"
#' @param x An object of class "summary.ocm", usually, a result of a call to summary.ocm.
#' @param ... Further arguments passed to or from other methods.
#' @keywords summary
#' @export

print.summary.ocmm <- function(x, ...)
{
  cat("Call:\n")
  print(x$call)
  cat("\n")
  printCoefmat(x$coefficients, P.values = TRUE, has.Pvalue = TRUE, ...)
}




#' @title Predict method for Continuous Ordinal Fits
#' 
#' @description Predicted values based on ocm object.
#' @param object An ocm object.
#' @param newdata optionally, a data frame in which to look for variables with which to predict. Note that all predictor variables should be present having the same names as the variables used to fit the model.
#' @param ... Further arguments passed to or from other methods.
#' @keywords predict
#' @export

predict.ocmm <- function(object, newdata=NULL, ...)
{
  formula <- object$formula
  params <- coef(object)
  if(is.null(newdata)){
    x <- object$x 
  }else{
    x <- model.matrix(object$formula, newdata)
  }
  len_beta <- ncol(x)
  ndens <- 100
  v <- seq(0.01, 0.99, length.out = ndens)
  modes <- NULL
  densities <- NULL
  #FIXME: rewrite efficiently
  for (subject in 1:nrow(x)){
    d.matrix <- matrix(rep(x[subject,], ndens), nrow = ndens, dimnames = list(as.character(1:ndens), colnames(x)), byrow = TRUE)
    densities <- rbind(densities, t(logdensity_glf(par = params, v = v, d.matrix = d.matrix, len_beta = len_beta)))
    modes <- c(modes, v[which.max(logdensity_glf(par = params, v = v, d.matrix = d.matrix, len_beta = len_beta))])
  }
  #y = logdensity_glf(par = params, v = v, d.matrix = x, len_beta = len_beta)
  #plot(v,y)
  pred <- list(mode = modes, density = densities, x = v, formula = formula, newdata = newdata)
  class(pred) <- "predict.ocm"
  return(pred)
}

#' @title Print the output of predict method
#' @description print method for class "predict.ocm"
#' @param x An object of class "predict.ocm".
#' @param ... Further arguments passed to or from other methods.
#' @keywords predict
#' @export

print.predict.ocmm <- function(x, ...)
{
  cat("\nThe data set used by the predict method contains",length(x$mode),"records.\n")
  cat("Call:\n")
  print(x$formula)
  cat("\nSummary of modes:\n")
  print(summary(x$mode), ...)
}

#' @title Plot the probability densities as from the output of the predict method
#' @description plot method for class "predict.ocm"
#' @param x An object of class "predict.ocm".
#' @param ... Further arguments passed to or from other methods.
#' @keywords predict, plot
#' @export

plot.predict.ocmm <- function(x, ...)
{
  cat("Call:\n")
  print(x$formula)
  cat("The data set used in the predict methos contains ",nrow(x$density)," records.\n")
  #cat("Please press 'enter' to start/advance plotting and q to quit.\n")
  for (i in 1:nrow(x$density)){
    input <- readline(paste("Press 'enter' to plot the probability density of record ",i,", 'q' to quit: ",sep=''))
    if (input == "q") break()
    plot(x$x, exp(x$density[i,]), ylab="Probability Density", main=paste("Record", i), xlab=paste("mode =", round(x$mode[i],3)), t='l')
    lines(rep(x$mode[i],2), c(0, max(exp(x$density[i,]))), lty=21)
  }
}


#' @title Plot method for Continuous Ordinal Fits
#' 
#' @description This function plots the g function as fitted in an ocm call.
#' @param x An ocm object.
#' @param CIs Indicates if confidence bands for the g function should be computed based on the Wald 95\% CIs or by bootstrapping. In  the latter case, bootstrapping can be performed using a random-x or a fixed-x resampling. 95\% CIs computed with either of the bootstrapping options are obtained with simple percentiles. 
#' @param R The number of bootstrap replicates. 
#' @param ... Further arguments passed to or from other methods.
#' @keywords plot
#' @export

plot.ocmm <- function(x, CIs = c('simple','rnd.x.bootstrap','fix.x.bootstrap','param.bootstrap'), R = 1000, ...)
{
  #FIXME: this works for glf only: make general?
  #FIXME: with bootstrapping, when a variable is a factor, it can go out of observation for some level making optim fail.
  CIs <- match.arg(CIs)
  R <- as.integer(R)
  M <- x$coefficients[1]
  params <- tail(coef(x), 2)
  len_p <- length(params)
  v <- seq(0.01, 0.99, by=0.01)
  gfun <- M + g_glf(v, params)
  xlim <- c(0,1)
  ylim <- c(min(gfun), max(gfun))
  if (CIs=='simple') {
    require(MASS)
    indices = c(1, len_p-1, len_p)
    params_g <- params[indices]
    vcov_g <- x$vcov[indices, indices]
    rparams <- mvrnorm(R, params_g, vcov_g, empirical=TRUE)
    #FIXME write efficiently
    #sds <- sqrt(diag(x$vcov))
    #sdM <- sds[1]
    #sM <- rnorm(R, M, sdM)
    #sdparams <- tail(sds, 2)
    #sparams <- matrix(rnorm(2*R, params, sdparams), ncol = 2, byrow = T)
    all_gfuns <- NULL
    for (i in 1:R){
      #all_gfuns <- rbind(all_gfuns, sM[i] + g_glf(v, sparams[i,]))
      all_gfuns <- rbind(all_gfuns, rparams[i,1] + g_glf(v, rparams[i,2:3]))
    }
    ci_low  <- apply(all_gfuns, 2, function(x)quantile(x, 0.025))
    ci_median <- apply(all_gfuns, 2, function(x)quantile(x, 0.5))
    ci_high <- apply(all_gfuns, 2, function(x)quantile(x, 0.975)) 
    ylim <- c(min(ci_low), max(ci_high))
  } else if (CIs=='rnd.x.bootstrap' | CIs=='fix.x.bootstrap'| CIs=='param.bootstrap'){
    require(boot)
    bs <- boot(x$data, eval(parse(text=CIs)), R, fit = x)
    all_gfuns <- NULL
    for (i in 1:R){
      all_gfuns <- rbind(all_gfuns, bs$t[i,1] + g_glf(v, tail(bs$t[i,],2)))
    }
    ci_low  <- apply(all_gfuns, 2, function(x)quantile(x, 0.025))
    ci_median <- apply(all_gfuns, 2, function(x)quantile(x, 0.5))
    ci_high <- apply(all_gfuns, 2, function(x)quantile(x, 0.975)) 
    ylim <- c(min(ci_low), max(ci_high))
  }
  plot(v, gfun, main='g function (95% CIs)', xlim = xlim, ylim = ylim, xlab = 'Continuous ordinal scale', ylab = '', t='l')
  lines(c(.5,.5), ylim, col='grey')
  lines(xlim, c(0, 0), col='grey')
  #CIs
  lines(v, ci_low, lty = 2)
  lines(v, ci_high, lty = 2)
  if (CIs=='simple' | CIs=='rnd.x.bootstrap' | CIs=='fix.x.bootstrap') lines(v, ci_median, lty = 2)
}

#' @title Anova method for Continuous Ordinal Fits
#' 
#' @description Comparison of continuous ordinal models in likelihood ratio tests.
#' @param object An ocm object.
#' @param ... one or more additional ocm objects.
#' @keywords anova
#' @export
#' @examples
#' fitLaplace = ocmm(vas ~ lasert1+lasert2+lasert3+ (1|ID), data=pain, quad="Laplace")
#' anova(fitLaplace, update(fitLaplace, . ~ . + localisa))


anova.ocmm <- function(object, ...)
  ### requires that ocm objects have components:
  ###  no.pars: no. parameters used
  ###  call$formula
  ###  link (character)
  ###  gfun (character)
  ###  logLik
  ###
{
  mc <- match.call()
  dots <- list(...)
  ## remove 'test' and 'type' arguments from dots-list:
  not.keep <- which(names(dots) %in% c("test", "type"))
  if(length(not.keep)) {
    message("'test' and 'type' arguments ignored in anova.ocm\n")
    dots <- dots[-not.keep]
  }
  if(length(dots) == 0)
    stop('anova is not implemented for a single "ocm" object')
  mlist <- c(list(object), dots)
  if(!all(sapply(mlist, function(model)
    inherits(model, c("ocm", "ocmm")))))
    stop("only 'ocm' and 'ocmm' objects are allowed")
  nfitted <- sapply(mlist, function(x) length(x$fitted.values))
  if(any(nfitted != nfitted[1L]))
    stop("models were not all fitted to the same dataset")
  no.par <- sapply(mlist, function(x) x$no.pars)
  ## order list with increasing no. par:
  ord <- order(no.par, decreasing=FALSE)
  mlist <- mlist[ord]
  no.par <- no.par[ord]
  no.tests <- length(mlist)
  ## extract formulas, links, gfun:
  forms <- sapply(mlist, function(x) deparse(x$call$formula))
  links <- sapply(mlist, function(x) x$link)
  gfun <- sapply(mlist, function(x) x$gfun)
  models <- data.frame(forms)
  models.names <- c('formula', "link", "gfun")
  models <- cbind(models, data.frame(links, gfun))
  ## extract AIC, logLik, statistics, df, p-values:
  AIC <- sapply(mlist, function(x) -2*x$logLik + 2*x$no.pars)
  logLiks <- sapply(mlist, function(x) x$logLik)
  statistic <- c(NA, 2*diff(sapply(mlist, function(x) x$logLik)))
  df <- c(NA, diff(no.par))
  pval <- c(NA, pchisq(statistic[-1], df[-1], lower.tail=FALSE))
  pval[!is.na(df) & df==0] <- NA
  ## collect results in data.frames:
  tab <- data.frame(no.par, AIC, logLiks, statistic, df, pval)
  tab.names <- c("no.par", "AIC", "logLik", "LR.stat", "df",
                 "Pr(>Chisq)")
  colnames(tab) <- tab.names
  #mnames <- sapply(as.list(mc), deparse)[-1]
  #rownames(tab) <- rownames(models) <- mnames[ord]
  rownames(tab) <- rownames(models) <- paste("Model ",1:length(mlist),":",sep='')
  colnames(models) <- models.names
  attr(tab, "models") <- models
  attr(tab, "heading") <-
    "Likelihood ratio tests of ordinal regression models for continuous scales:\n"
  class(tab) <- c("anova.ocm", "data.frame")
  tab
}

#' @export

#' @title Print anova.ocm objects
#' 
#' @description Print the results of the comparison of continuous ordinal models in likelihood ratio tests.
#' @param x An object of class "anova.ocm".
#' @param ... Further arguments passed to or from other methods.
#' @keywords summary, anova
#' @export

print.anova.ocmm <-
  function(x, digits=max(getOption("digits") - 2, 3),
           signif.stars=getOption("show.signif.stars"), ...)
  {
    if (!is.null(heading <- attr(x, "heading")))
      cat(heading, "\n")
    models <- attr(x, "models")
    #row.names(models) <- paste("Model ",1:nrow(models),":",sep='')
    print(models, right=FALSE)
    cat("\n")
    printCoefmat(x, digits=digits, signif.stars=signif.stars,
                 tst.ind=4, cs.ind=NULL, # zap.ind=2, #c(1,5),
                 P.values=TRUE, has.Pvalue=TRUE, na.print="", ...)
    return(invisible(x))
  }