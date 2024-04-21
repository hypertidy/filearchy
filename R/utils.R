## switch on a being NULL, give b instead
"%||%" <- function(a, b) {
  if (!is.null(a)) a else b
}

