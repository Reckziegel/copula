setClass("fitCopula",
         representation(est = "numeric",
                        var.est = "matrix",
                        loglik = "numeric",
                        convergence = "integer",
                        nsample = "integer",
                        copula = "copula"),
         validity = function(object) TRUE,
         contains = list()
         )

loglikCopula <- function(param, x, copula) {
  copula@parameters <- param
  sum(log(dcopula(copula, x)))
}

fitCopula <- function(data, copula, start,
                      optim.control=list(NULL), method="BFGS") {
  if (copula@dimension != ncol(data))
    stop("The dimention of the data and copual not match.\n")
  if (length(copula@parameters) != length(start))
    stop("The length of start and copula parameters not match.\n")

  control <- c(optim.control, fnscale=-1)
  fit <- optim(start, loglikCopula, copula = copula, x = data, control=control)
  if (fit$convergence > 0)
    warning("possible convergence problem: optim gave code=", fit$convergence)
  copula@parameters <- fit$par
  loglik <- fit$val

  fit.last <- optim(copula@parameters, loglikCopula, copula=copula, x =data, control=c(control, maxit=1), hess=TRUE)
    
  ans <- new("fitCopula",
             est = fit$par,
             var.est = solve(-fit.last$hess),
             loglik = loglik,
             convergence = fit$convergence,
             nsample = nrow(data),
             copula = copula)
  ans
}
        
  

setClass("fitMvdc",
         representation(est = "numeric",
                        var.est = "matrix",
                        loglik = "numeric",
                        convergence = "integer",
                        nsample = "integer",
                        mvdc = "mvdc"),
         validity = function(object) TRUE,
         contains = list()         
         )



loglikMvdc <- function(param, x, mvdc) {
  p <- mvdc@copula@dimension
  marNpar <- unlist(lapply(mvdc@paramMargins, length))
  idx2 <- cumsum(marNpar)
  idx1 <- idx2 - marNpar + 1
  for (i in 1:p) {
    if (marNpar[i] > 0) {
      ## parnames <- mvdc@paramMargins[[i]]
      par <- param[idx1[i]: idx2[i]]
      ## names(par) <- parnames
      ## mvdc@paramMargins[i] <- as.list(par)
      for (j in 1:marNpar[i]) mvdc@paramMargins[[i]][j] <- par[j]
    }      
  }
  mvdc@copula@parameters <- param[- (1:rev(idx2)[1])]
  sum(log(dmvdc(mvdc, x)))
}

fitMvdc <- function(data, mvdc, start,
                    optim.control=list(NULL), method="BFGS") {
  copula <- mvdc@copula
  if (copula@dimension != ncol(data))
    stop("The dimention of the data and copual not match.\n")
  marNpar <- unlist(lapply(mvdc@paramMargins, length))
  if (length(copula@parameters) + sum(marNpar) != length(start))
    stop("The length of start and mvdc parameters not match.\n")

  control <- c(optim.control, fnscale=-1)
  fit <- optim(start, loglikMvdc, mvdc=mvdc, x = data, control=control)
  if (fit$convergence > 0)
    warning("possible convergence problem: optim gave code=", fit$convergence)
  loglik <- fit$val

  fit.last <- optim(fit$par, loglikMvdc, mvdc=mvdc, x =data, control=c(control, maxit=1), hess=TRUE)
    
  ans <- new("fitMvdc",
             est = fit$par,
             var.est = solve(-fit.last$hess),
             loglik = loglik,
             convergence = fit$convergence,
             nsample = nrow(data),
             mvdc = mvdc)
  ans
}

setClass("summaryFitCopula",
         representation(loglik = "numeric",
                        convergence = "integer",
                        parameters = "data.frame"),
         validity = function(object) TRUE,
         contains = list()
         )

summaryFitCopula <- function(object) {
  est <- object@est
  se <- sqrt(diag(object@var.est))
  zvalue <- est / se
  pvalue <- (1 - pnorm(abs(zvalue))) * 2
  parameters <- data.frame(est, se, zvalue, pvalue)
  dimnames(parameters) <-
    list(object@copula@param.names,
         c("Estimate", "Std. Error", "z value", "Pr(>|z|)"))
  ret <- new("summaryFitCopula",
             loglik = object@loglik,
             convergence = object@convergence,
             parameters = parameters)
  ret
}

showFitCopula <- function(object) {
  foo <- summaryFitCopula(object)
  cat("The ML estimation is based on ", object@nsample, " observations.\n")
  print(foo@parameters)
  cat("The maximized loglikelihood is ", foo@loglik, "\n")
  cat("The convergence code is ", foo@convergence, "\n")
}


setClass("summaryFitMvdc",
         representation(loglik = "numeric",
                        convergence = "integer",
                        parameters = "data.frame"),
         validity = function(object) TRUE,
         contains = list()
         )

summaryFitMvdc <- function(object) {
  est <- object@est
  se <- sqrt(diag(object@var.est))
  zvalue <- est / se
  pvalue <- (1 - pnorm(abs(zvalue))) * 2
  ans <- object[c("loglik", "convergence")]
  parameters <- data.frame(est, se, zvalue, pvalue)
  marNpar <- unlist(lapply(object@mvdc@paramMargins, length))
  p <- object@mvdc@copula@dimension

  pnames <- c(paste(paste("m", rep(1:p, marNpar), sep=""),
                    unlist(lapply(object@mvdc@paramMargins, names)), sep="."),
              object@mvdc@copula@param.names)
  
  dimnames(parameters) <-
    list(pnames,
         c("Estimate", "Std. Error", "z value", "Pr(>|z|)"))
  ret <- new("summaryFitMvdc",
             loglik = object@loglik,
             convergence = object@convergence,
             parameters = parameters)
  ret
}

showFitMvdc <- function(object) {
  foo <- summaryFitMvdc(object)
  cat("The ML estimation is based on ", object@nsample, " observations.\n")
  p <- object@mvdc@copula@dimension
  marNpar <- unlist(lapply(object@mvdc@paramMargins, length))
  idx2 <- cumsum(marNpar)
  idx1 <- idx2 - marNpar + 1
  for (i in 1:p) {
    cat("Margin ", i, ":\n")
    print(foo@parameters[idx1[i]:idx2[i], 1:2, drop=FALSE])
  }
  cat("Copula:\n")
  print(foo@parameters[- (1:rev(idx2)[1]), 1:2, drop=FALSE])
  
  cat("The maximized loglikelihood is ", foo@loglik, "\n")
  cat("The convergence code is ", foo@convergence, "\n")
}

setMethod("show", signature("fitCopula"), showFitCopula)
setMethod("show", signature("fitMvdc"), showFitMvdc)

setMethod("summary", signature("fitCopula"), summaryFitCopula)
setMethod("summary", signature("fitMvdc"), summaryFitMvdc)
          