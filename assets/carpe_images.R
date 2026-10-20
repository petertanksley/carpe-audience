# carpe_images.R — photo preparation for Carpe Audience decks (Keyes 2011, chs. 12-14)
#
#   source(file.path(Sys.getenv("CARPE_SKILL", "~/.claude/skills/carpe-audience"), "assets", "carpe_images.R"))
#
# carpe_promote()  candidate from bananarama (JPEG data in a .png name) -> images/<name>.jpg
# carpe_crop()     crop to a target aspect around a focal point (p. 71: picture bigger than the
#                  slide, focal point moved onto a thirds intersection). Use aspect = "split" for
#                  the two-thirds split layout (p. 75).
# carpe_vignette() fade-to-black radial gradient baked into the pixels (p. 76), so type reads over
#                  the photo without washing out its colour the way background-opacity does.
#                  Baked in, it survives embed-resources and needs no CSS.
#
# Slide usage:
#   ## {.left-third background-image="images/x_vig.jpg" background-size="cover" background-position="70% 50%"}
#   ## {.split background-image="images/x_split.jpg" background-size="auto 100%" background-position="left center" background-repeat="no-repeat"}
#      (add .flip and background-position="right center" for a photo on the right)

carpe_promote <- function(src, name, dir = "images") {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  img <- magick::image_read(src)                     # sniffs the real format
  out <- file.path(dir, paste0(name, ".jpg"))
  magick::image_write(img, out, format = "jpeg", quality = 92)
  message(sprintf("%s -> %s (%s)", basename(src), out, paste(dim(magick::image_data(img))[2:3], collapse = "x")))
  invisible(out)
}

# focus = c(x, y) in 0..1 of the source image: the point to keep in view (the subject).
carpe_crop <- function(src, out = NULL, aspect = 16 / 9, focus = c(0.5, 0.5)) {
  if (identical(aspect, "split")) aspect <- (1280 * 2 / 3) / 720           # 0.667 of a 16:9 frame
  img <- magick::image_read(src)
  info <- magick::image_info(img); W <- info$width; H <- info$height
  if (W / H > aspect) { h <- H; w <- round(H * aspect) } else { w <- W; h <- round(W / aspect) }
  x0 <- max(0, min(W - w, round(focus[1] * W - w / 2)))
  y0 <- max(0, min(H - h, round(focus[2] * H - h / 2)))
  img <- magick::image_crop(img, magick::geometry_area(w, h, x0, y0))
  out <- out %||% sub("(\\.[A-Za-z]+)?$", "_crop.jpg", src)
  magick::image_write(img, out, format = "jpeg", quality = 92)
  if (w < 1280 * (if (aspect < 1.5) 2 / 3 else 1))
    warning(sprintf("%s is %dx%d after cropping: below the 1280-wide floor for its slot (p. 75)", out, w, h))
  invisible(out)
}

# inner: radius (fraction of the half-diagonal) that stays untouched; strength: darkness at the corners.
# centre: where the light falls, c(x, y) in 0..1 (put it on the subject, not the type).
carpe_vignette <- function(src, out = NULL, inner = 0.45, strength = 0.85, centre = c(0.5, 0.5)) {
  img <- magick::image_read(src)
  a <- as.integer(magick::image_data(img, "rgb"))           # H x W x 3, 0..255
  H <- dim(a)[1]; W <- dim(a)[2]
  yy <- (matrix(rep(seq_len(H), W), H) - centre[2] * H) / (H / 2)
  xx <- (matrix(rep(seq_len(W), each = H), H) - centre[1] * W) / (W / 2)
  r <- sqrt(xx^2 + yy^2) / sqrt(2)
  k <- 1 - strength * pmin(1, pmax(0, (r - inner) / (1 - inner)))^1.6
  for (ch in 1:3) a[, , ch] <- a[, , ch] * k
  out <- out %||% sub("(\\.[A-Za-z]+)?$", "_vig.jpg", src)
  magick::image_write(magick::image_read(a / 255), out, format = "jpeg", quality = 92)
  invisible(out)
}

`%||%` <- function(a, b) if (is.null(a)) b else a

# Refresh a talk's copies of the theme files from the skill. Talks keep COPIES (never
# symlinks), so a skill update does not reach an existing deck until this runs.
carpe_sync <- function(talk_dir = ".") {
  a <- file.path(Sys.getenv("CARPE_SKILL", "~/.claude/skills/carpe-audience"), "assets")
  ok <- file.copy(file.path(a, c("carpe.scss", "carpe-fonts.css")), talk_dir, overwrite = TRUE)
  dir.create(file.path(talk_dir, "fonts"), showWarnings = FALSE)
  ok2 <- file.copy(list.files(file.path(a, "fonts"), full.names = TRUE), file.path(talk_dir, "fonts"), overwrite = TRUE)
  message(sprintf("carpe_sync: %d theme files, %d font files refreshed in %s", sum(ok), sum(ok2), normalizePath(talk_dir)))
  invisible(all(ok, ok2))
}
