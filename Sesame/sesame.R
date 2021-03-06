#' ---
#' title: "Regression and Other Stories: Sesame street"
#' author: "Andrew Gelman, Jennifer Hill, Aki Vehtari"
#' date: "`r format(Sys.Date())`"
#' ---

#' Causal analysis of Sesame Street experiment. See Chapters 18 and 21
#' in Regression and Other Stories.
#' 
#' -------------
#' 

#+ setup, include=FALSE
knitr::opts_chunk$set(message=FALSE, error=FALSE, warning=FALSE, comment=NA)

#' **Load packages**
library("rprojroot")
root<-has_dirname("ROS-Examples")$make_fix_file()
library("rstanarm")
library("brms")
library("foreign")

#' **Load data**
sesame <- read.dta(file=root("Sesame/data","sesame.dta"))
sesame$watched <- ifelse(sesame$viewcat==1, 0, 1)
sesame$encouraged <- ifelse(sesame$viewenc==2, 0, 1)
sesame$y <- sesame$postlet
sesame$pretest <- sesame$prelet

#' **Estimate the percentage of children actually induced to watch
#' Sesame Street by the intervention**
fit_1a <- stan_glm(watched ~ encouraged, data=sesame, refresh=0)
print(fit_1a, digits=2)

#' **Compute the intent-to-treat estimate, obtained in this case using
#' the regression of the outcome (in the data, labeled postlet, that
#' is, the post-treatment measurement of the letter recognition task)
#' on the instrument**
fit_1b <- stan_glm(postlet ~ encouraged, data=sesame, refresh=0)
print(fit_1b, digits=2)

#' **"Inflate" by dividing by the percentage of children affected by
#' the intervention**
iv_est <- coef(fit_1b)["encouraged"] / coef(fit_1a)["encouraged"]

#' **Two stage approach**
#'
#' The first step is to regress the "treatment" variable---an
#' indicator for regular watching (watched)---on the randomized
#' instrument, encouragement to watch (encouraged).  Then we plug
#' predicted values of watched into the equation predicting the letter
#' recognition outcome.
fit_2a <- stan_glm(watched ~ encouraged, data=sesame, refresh=0)
sesame$watched_hat_2 <- fit_2a$fitted
fit_2b <- stan_glm(postlet ~ watched_hat_2, data=sesame, refresh=0)
print(fit_2b, digits = 2)

#' **Two stage approach with adjusting for covariates in an instrumental variables framework**
fit_3a <- stan_glm(watched ~ encouraged + prelet + as.factor(site) + setting,
                   data=sesame, refresh=0)
watched_hat_3 <- fit_3a$fitted
fit_3b <- stan_glm(postlet ~ watched_hat_3 + prelet + as.factor(site) + setting,
                   data=sesame, refresh=0)
print(fit_3b, digits = 2)

#' **Regress the outcome on predicted compliance and covariates**
#'
#' Save the predictor matrix from this second-stage
#' regression.
fit_3c <- stan_glm(postlet ~ watched_hat_3 + prelet + as.factor(site) + setting,
                   x=TRUE, data=sesame)
X_adj <- fit_3c$x
X_adj[,"watched_hat_3"] <- sesame$watched
#' **Compute the standard deviation of the adjusted residuals**
residual_sd_adj <- sd(sesame$postlet - X_adj %*% coef(fit_3c))
se_adj <- se(fit_3c)["watched_hat_3"] * residual_sd_adj / sigma(fit_3c)
print(se_adj, digits=2)

#' **Perform two-stage approach automatically using brms**
f1 <- bf(watched ~ encour)
f2 <- bf(postlet ~ watched)
IV_brm <- brm(f1 + f2, data=sesame)
print(IV_brm)

#' **Perform two-stage approach incorporating other pre-treatment
#' variables as controls using brms**
f1 <- bf(watched ~ encour + prelet + setting + factor(site))
f2 <- bf(postlet ~ watched + prelet + setting + factor(site))
IV_brm_2 <- brm(f1 + f2, data=sesame)
print(IV_brm_2)
