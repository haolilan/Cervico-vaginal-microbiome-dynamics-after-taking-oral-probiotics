

# function
plot_roc <- function(response, predictor, direction = "auto") {
  print(
    paste0(
      "warning: levels of respone is ",
      paste(levels(as.factor(response)), collapse = ", "),
      " and should corresponding to controal and case, the default direction is auto"
    )
  )
  roc.obj <-
    roc(
      response,
      predictor,
      percent = T,
      ci = T,
      plot = T,
      direction = direction
    )
  ci.se.obj <- ci.se(roc.obj, specificities = seq(0, 100, 5))
  plot(ci.se.obj,
       type = "shape",
       col = rgb(0, 1, 0, alpha = 0.2))
  plot(ci.se.obj, type = "bars")
  plot(roc.obj, col = 2, add = T)
  txt <-
    c(paste("AUC=", round(roc.obj$ci[2], 2), "%"),
      paste(
        "95% CI:",
        round(roc.obj$ci[1], 2),
        "%-",
        round(roc.obj$ci[3], 2),
        "%"
      ))
  legend("bottomright", txt)
}

##rfcv
# function
rfcv1 <-
  function(trainx,
           trainy,
           cv.fold = 5,
           scale = "log",
           step = 0.5,
           mtry = function(p)
             max(1, floor(sqrt(p))),
           recursive = FALSE,
           ipt = NULL,
           ...) {
    classRF <- is.factor(trainy)
    n <- nrow(trainx)
    p <- ncol(trainx)
    if (scale == "log") {
      k <- floor(log(p, base = 1 / step))
      n.var <- round(p * step ^ (0:(k - 1)))
      same <- diff(n.var) == 0
      if (any(same))
        n.var <- n.var[-which(same)]
      if (!1 %in% n.var)
        n.var <- c(n.var, 1)
    } else {
      n.var <- seq(from = p, to = 1, by = step)
    }
    k <- length(n.var)
    cv.pred <- vector(k, mode = "list")
    for (i in 1:k)
      cv.pred[[i]] <- trainy
    if (classRF) {
      f <- trainy
      if (is.null(ipt))
        ipt <- nlevels(trainy) + 1
    } else {
      f <- factor(rep(1:5, length = length(trainy))[order(order(trainy))])
      if (is.null(ipt))
        ipt <- 1
    }
    nlvl <- table(f)
    idx <- numeric(n)
    for (i in 1:length(nlvl)) {
      idx[which(f == levels(f)[i])] <-
        sample(rep(1:cv.fold, length = nlvl[i]))
    }
    res = list()
    for (i in 1:cv.fold) {
      all.rf <-
        randomForest(
          trainx[idx != i, , drop = FALSE],
          trainy[idx != i],
          trainx[idx == i, , drop = FALSE],
          trainy[idx ==
                   i],
          mtry = mtry(p),
          importance = TRUE,
          ...
        )
      cv.pred[[1]][idx == i] <- all.rf$test$predicted
      impvar <-
        (1:p)[order(all.rf$importance[, ipt], decreasing = TRUE)]
      res[[i]] <- impvar
      for (j in 2:k) {
        imp.idx <- impvar[1:n.var[j]]
        sub.rf <-
          randomForest(
            trainx[idx != i, imp.idx, drop = FALSE],
            trainy[idx != i],
            trainx[idx == i, imp.idx, drop = FALSE],
            trainy[idx == i],
            mtry = mtry(n.var[j]),
            importance = recursive,
            ...
          )
        cv.pred[[j]][idx == i] <- sub.rf$test$predicted
        if (recursive) {
          impvar <-
            (1:length(imp.idx))[order(sub.rf$importance[, ipt], decreasing = TRUE)]
        }
        NULL
      }
      NULL
    }
    if (classRF) {
      error.cv <- sapply(cv.pred, function(x)
        mean(trainy != x))
    } else {
      error.cv <- sapply(cv.pred, function(x)
        mean((trainy - x) ^ 2))
    }
    names(error.cv) <- names(cv.pred) <- n.var
    list(
      n.var = n.var,
      error.cv = error.cv,
      predicted = cv.pred,
      res = res
    )
  }
