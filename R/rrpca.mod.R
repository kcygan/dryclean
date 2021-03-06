#' @title  Randomized robust principal component analysis (rrpca).
#
#' @description Robust principal components analysis separates a matrix into a low-rank plus sparse component.
#
#' @details
#' Robust principal component analysis (RPCA) is a method for the robust seperation of a
#' a rectangular \eqn{(m,n)} matrix \eqn{A} into a low-rank component \eqn{L} and a
#' sparse comonent \eqn{S}: 
#'
#' \deqn{ A = L + S}
#'
#' To decompose the matrix, we use the inexact augmented Lagrange multiplier
#' method (IALM). The algorithm can be used in combination with either the randomized or deterministic SVD. 
#'
#'
#' @param A       array_like; \cr
#'                a real \eqn{(m, n)} input matrix (or data frame) to be decomposed. \cr
#'                na.omit is applied, if the data contain \eqn{NA}s.
#'
#' @param lambda  scalar, optional; \cr
#'                tuning parameter (default \eqn{lambda = max(m,n)^-0.5}).
#'
#' @param maxiter integer, optional; \cr
#'                maximum number of iterations (default \eqn{maxiter = 20}).
#'
#' @param tol     scalar, optional; \cr
#'                precision parameter (default \eqn{tol = 1.0e-5}).
#'
#' @param na.remove boolean, optional; \cr
#'                Remove NA values and substitute with zeros
#'
#' @param p       integer, optional; \cr
#'                oversampling parameter for \eqn{rsvd} (default \eqn{p=10}), see \code{\link{rsvd}}.
#'
#' @param q       integer, optional; \cr
#'                number of additional power iterations for \eqn{rsvd} (default \eqn{q=2}), see \code{\link{rsvd}}.
#'
#' @param trace   bool, optional; \cr
#'                print progress.
#'                
#' @param rand    bool, optional; \cr
#'                if (\eqn{TRUE}), the \eqn{rsvd} routine is used, otherwise \eqn{svd} is used.
#'
#'
#' @return \code{rrpca} returns a list containing the following components:
#'    \item{L}{  array_like; \cr
#'              low-rank component; \eqn{(m, n)} dimensional array.
#'    }
#'    \item{S}{  array_like \cr
#'               sparse component; \eqn{(m, n)} dimensional array.
#'    }
#'
#'
#' @author N. Benjamin Erichson, \email{erichson@uw.edu}
#'
#' @references
#' \itemize{
#'   \item  [1] Lin, Zhouchen, Minming Chen, and Yi Ma.
#'          "The augmented lagrange multiplier method for exact
#'          recovery of corrupted low-rank matrices." (2010).
#'          (available at arXiv \url{http://arxiv.org/abs/1009.5055}).
#'
#'   \item  [2] N. B. Erichson, S. Voronin, S. Brunton, J. N. Kutz.
#'          "Randomized matrix decompositions using R" (2016).
#'          (available at `arXiv \url{http://arxiv.org/abs/1608.02148}).
#' }
#'
#' @examples
#' library(rsvd)
#'
#' # Create toy video
#' # background frame
#' xy <- seq(-50, 50, length.out=100)
#' mgrid <- list( x=outer(xy*0,xy,FUN="+"), y=outer(xy,xy*0,FUN="+") )
#' bg <- 0.1*exp(sin(-mgrid$x**2-mgrid$y**2))
#' toyVideo <- matrix(rep(c(bg), 100), 100*100, 100)
#'
#' # add moving object
#' for(i in 1:90) {
#'   mobject <- matrix(0, 100, 100)
#'   mobject[i:(10+i), 45:55] <- 0.2
#'   toyVideo[,i] =  toyVideo[,i] + c( mobject )
#' }
#'
#' # Foreground/Background separation
#' out <- rrpca(toyVideo, trace=TRUE)
#'
#' # Display results of the seperation for the 10th frame
#' par(mfrow=c(1,4))
#' image(matrix(bg, ncol=100, nrow=100)) #true background
#' image(matrix(toyVideo[,10], ncol=100, nrow=100)) # frame
#' image(matrix(out$L[,10], ncol=100, nrow=100)) # seperated background
#' image(matrix(out$S[,10], ncol=100, nrow=100)) #seperated foreground



#' @export
rrpca <- function(A, lambda=NULL, maxiter=50, tol=1.0e-5, p=10, q=2, trace=FALSE, rand=TRUE, na.remove = FALSE) UseMethod("rrpca")

#' @export
rrpca.default <- function(A, lambda=NULL, maxiter=50, tol=1.0e-5, p=10, q=2, trace=FALSE, rand=TRUE, na.remove = FALSE) {
  #*************************************************************************
  #***        Author: N. Benjamin Erichson <nbe@st-andrews.ac.uk>        ***
  #***                              <2016>                               ***
  #***                       License: BSD 3 clause                       ***
  #*************************************************************************
  ## A <- as.matrix(A) ## Addy removed this line

  A <- as.matrix(A); gc()
  A <- Matrix(A); gc()  
  m <- nrow(A)
  n <- ncol(A)

  rrpcaObj = list(L = NULL,
                  S = NULL,
                  err = NULL)


  # Set target rank
  k <- 1
  if(k > min(m,n)) rrpcaObj$k <- min(m,n)

    if(trace==TRUE){message("0's")}
  # Deal with missing values
    if (na.remove){
        is.na(A) <- 0
    }
    
  if(trace==TRUE){message("0's done")}
  ## Set lambda, gamma, rho

  if(is.null(lambda)) lambda <- max(m,n)**-0.5
  gamma <- 1.25
  rho <- 1.5

  if(rand == TRUE) {
    svdalg = 'rsvd'
  } else { 
      svdalg = 'svd' 
  }  
  
  # Compute matrix norms
  spectralNorm <- switch(svdalg,
                    svd = norm(as.matrix(A), "2"),
                    rsvd = rsvd(as.matrix(A), k=1, p=10, q=1, nu=0, nv=0)$d,
                    stop("Selected SVD algorithm is not supported!")
                    )
    
  if(trace==TRUE){message("svd done")}
    
  infNorm <- norm(as.matrix(A) , "I") / lambda
  dualNorm <- max(spectralNorm , infNorm)
  froNorm <- norm(as.matrix(A) , "F")
    
  if(trace==TRUE){message("done with norms")}

    gc()
    
  # Initalize Lagrange multiplier
    Z <- A / dualNorm
    gc()

    if(trace==TRUE){message("Z done")}

  # Initialize tuning parameter
  mu <- gamma / spectralNorm
  mubar <- mu * 1e7
  mu <- min( mu * rho , mubar )
  muinv <- 1 / mu

  ## Init low-rank and sparse matrix
  L = Matrix(0, nrow = m, ncol = n, sparse = TRUE) ## Addy, sparseness to initiate
  S = matrix(0, nrow = m, ncol = n)  ## Addy, removed this. Redundant
  if(trace==TRUE){message("starting iteration")}
  niter <- 1
  err <- 1
  while(err > tol && niter <= maxiter) {

      #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      # Update S using soft-threshold
      #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      if(trace==TRUE){message("iteration starts")}
      gc()
      epsi = lambda / mu
      ##temp1 <- (L + (Z / mu))
      ##gc()
      ##temp_S <- A - temp1
      ##temp_S = A - L + ((A / dualNorm) / mu)
      temp_S = A - L + Z / mu
      ## temp_S <- Matrix(temp_S, sparse = TRUE)
      gc()
      if(trace==TRUE){message("temp_S done")}
      ##S = Matrix(0, nrow = m, ncol = n, sparse = TRUE)

      idxL <- seq_along(temp_S)[as.numeric(temp_S) < -epsi]
      idxH <- seq_along(temp_S)[as.numeric(temp_S) > epsi]

      gc()
      if(trace==TRUE){message("indices seq_along done")}
      #idxL <- which(temp_S < -epsi)
      #idxH <- which(temp_S > epsi)
      S[idxL] <- temp_S[idxL] + epsi
      gc()
      if(trace==TRUE){message("done idxL")}
      S[idxH] <- temp_S[idxH] - epsi
      gc()
      if(trace==TRUE){message("done soft threshold")}
      ##rm(temp_S)
      gc()
      #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      #Singular Value Decomposition
      #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      R <- A - S + Z / mu
      ## R <- A - S + ((A / dualNorm) / mu)
      gc()
      if(trace==TRUE){message("R done")}
      
      if(svdalg == 'svd') svd_out <- svd(R)
      if(svdalg == 'rsvd') {
        if(k > min(m,n)/5 ) auto_svd = 'svd' else auto_svd = 'rsvd' 
      
        svd_out <- switch(auto_svd,
                          svd = svd(R),
                          rsvd = rsvd(R, k=k+10, p=p, q=q)) 
      }  

      if(trace==TRUE){message("done svd")}
      rm(R)
      gc()
      #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      # Predict optimal rank and update
      #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      svp = sum(svd_out$d > 1/mu)
      
      if(svp <= k){
        k = min(svp + 1, n)
      } else {
        k = min(svp + round(0.05 * n), n)
      }

      if(trace==TRUE){message("done opt rank")}
      #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      # Truncate SVD and update L
      #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      # rrpcaObj$L =  svd_out$u[,1:rrpcaObj$k] %*% diag(svd_out$d[1:rrpcaObj$k] - muinv, nrow=rrpcaObj$k, ncol=rrpcaObj$k)  %*% t(svd_out$v[,1:rrpcaObj$k])
      L =  t(t(svd_out$u[,1:svp]) * (svd_out$d[1:svp] - 1/mu)) %*% t(svd_out$v[,1:svp])
      gc()

      if(trace==TRUE){message("done updating L")}
      #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      # Compute error
      #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      ##if (niter %% 3 == 0){
      Astar = A - L - S
      if(trace==TRUE){message("done A*")}

      gc()
      
      Z = Z + Astar * mu
      if(trace==TRUE){message("Z updated")}

      gc()

      ##if (niter == 1 | niter %% 2 == 0){
          err = norm( Astar , 'F') / froNorm
          rrpcaObj$err <- c(rrpcaObj$err, err)
          
          if(trace==TRUE){
              cat('\n', paste0('Iteration: ', niter ), paste0(' predicted rank = ', svp ), paste0(' target rank k = ', k ),  paste0(' Fro. error = ', rrpcaObj$err[niter] ))
          }
      ##}

      rm(Astar)
      gc()
      #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      # Update mu
      #~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
      mu = min(mu * rho, mubar);
      muinv = 1 / mu

      niter =  niter + 1

      gc() ### Addy, Added garbage collection

  }# End while loop
    rrpcaObj$L <- L
    rrpcaObj$S <- S
    rrpcaObj$k <- k
    message("GiddyUp")
    
  class(rrpcaObj) <- "rrpca"
  return( rrpcaObj )

}



