library(rethinking)
library(magrittr)

# load data
data(Howell1)
d = Howell1

curve(dnorm(x, 178, 20), from=100, to=250)
curve(dunif(x, 0, 50), from=-10, to=60)

nsamp = 1e4
set.seed(2020)

dnorm_like = function(xx) {
  # Return a function for normal density
  # with the same mean and std. deviation
  # as `xx`
  return(function(y) dnorm(y, mean=mean(xx), sd=sd(xx)))
}

sample_mu = rnorm(nsamp, 178, 20)
sample_sigma = runif(nsamp, 0, 50)
prior_h = rnorm(nsamp, sample_mu, sample_sigma)
prior_h %>% density %>% plot
curve(dnorm_like(prior_h)(x), add=TRUE, col='orange')

#  4.14
d2 = d[d$age >= 18, ]  ## only adults
mus = seq(from=140, to=160, length.out=200)  ## space of means
sigmas = seq(from=5, to=9, length.out=200)   ## space of st devs
post = expand.grid(mu=mus, sigma=sigmas)     ## cartesian product

# define likelihood of data given mu and sigma
post$LL = sapply(1:nrow(post), function(i) {
  sum(dnorm(
    d2$height,
    mean=post$mu[i],
    sd=post$sigma[i],
    log=TRUE   ## so we can sum
  ))
})

# define priors for each mu and sigma, in log space
mu_prior = dnorm(post$mu, mean=178, sd=20, log=TRUE)
sigma_prior = dunif(post$sigma, min=0, max=50, log=TRUE)
post$prod = post$LL + mu_prior + sigma_prior  ## still in log space
# bringing numbers close to 0 in log space
# is equivalent to multiplying by constant in linear space
# needed for machine precision before exp(), otherwise all compute to 0
post$prod = exp(post$prod - max(post$prod))

# contour plot
contour_xyz(post$mu, post$sigma, post$prod)

# heatmap
image_xyz(post$mu, post$sigma, post$prod)

# sample from posterior
sample_idx = sample(1:nrow(post), size=1e4, prob=post$prod, replace=TRUE)
sample_mu = post$mu[sample_idx]
sample_sigma = post$sigma[sample_idx]

# look at the sampled values
plot(sample_mu, sample_sigma, cex=1, pch=16, col=col.alpha(rangi2, 0.1))

# quadratic approximation
flist = alist(
  height ~ dnorm(mu, sigma),
  mu ~ dnorm(178, 20),
  sigma ~ dunif(0, 50)
)

m4_1 = map(flist, data=d2)
precis(m4_1)

m4_2 = map(
  alist(
    height ~ dnorm(mu, sigma),
    mu ~ dnorm(178, 0.1),
    sigma ~ dunif(0, 50)
  ),
  data=d2
)
precis(m4_2)

vcov(m4_1)
m4_1 %>% vcov %>% cov2cor

post2 = extract.samples(m4_1, n=1e4)
post2 %>% head
post2 %>% precis

library(MASS)
post <- mvrnorm(n=1e4, mu=m4_1@coef, Sigma=m4_1@vcov)

m4_1_logsigma <- map(
  alist(
    height ~ dnorm(mu, exp(log_sigma)),
    mu ~ dnorm(178, 20),
    log_sigma ~ dnorm(2, 10)
  ), data = d2)
post_logsigma <- extract.samples(m4_1_logsigma)
sigma <- exp(post_logsigma$log_sigma)

plot(height ~ weight, d2)


m4_3 <- map(
  alist(
    height ~ dnorm(mu, sigma),
    mu <- a + b*weight,
    a ~ dnorm(156, 100),
    b ~ dnorm(0, 10), 
    sigma ~ dunif(0, 50)
  ),
  data=d2
)

precis(m4_3, corr=TRUE)
cov2cor(vcov(m4_3))

d2$weight.c <- d2$weight - mean(d2$weight)
m4_4 <- map(
  alist(
    height ~ dnorm(mu, sigma),
    mu <- a + b*weight.c,
    a ~ dnorm(178, 100),
    b ~ dnorm(0, 10),
    sigma ~ dunif(0, 50)
  ),
  data=d2)
precis(m4_4, corr=TRUE)
mean(d2$height)

plot(height ~ weight, data=d2)
abline(m4_3)

post <- extract.samples(m4_3)
post[1:5,]
