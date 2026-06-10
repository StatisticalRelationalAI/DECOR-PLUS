library(ggplot2)
library(dplyr)
library(tikzDevice)

use_tikz = TRUE

file_main = "results-prepared-main.csv"
file_app  = "results-prepared-appendix.csv"

# Display names (also the factor order for legends).
algo_levels = c(
  "DECOR", "DECOR+", "A-DECOR", "Brute-Force",
  "DECOR+ (SBF)", "DECOR+ (LGF)",
  "DECOR+ (SCSF)", "DECOR+ (SMCF)",
  "CC-DECOR"
)

family_levels = c("DECOR", "DECOR+", "A-DECOR", "Brute-Force")

# Apriori-style pair: A-DECOR and CC-DECOR (shown together in their own plot).
apriori_levels = c("A-DECOR", "CC-DECOR")

decorplus_levels = c(
  "DECOR+", "DECOR+ (SBF)", "DECOR+ (LGF)",
  "DECOR+ (SCSF)", "DECOR+ (SMCF)"
)

# Style-guide palette (six colors, five line types, five shapes).
palette_colors = c(
  rgb(247, 192,  26, maxColorValue=255),
  rgb( 78, 155, 133, maxColorValue=255),
  rgb( 37, 122, 164, maxColorValue=255),
  rgb( 86,  51,  94, maxColorValue=255),
  rgb(126,  41,  84, maxColorValue=255),
  rgb(128, 128, 128, maxColorValue=255)
)
palette_ltys   = c("solid", "dashed", "dotted", "longdash", "twodash")
palette_shapes = c(19, 17, 15, 8, 23)

# Family mapping: pick the first four palette entries so DECOR+ stays green
# across plots.
family_colors = setNames(
  c(palette_colors[1], palette_colors[2], palette_colors[3], palette_colors[4]),
  family_levels
)
family_ltys   = setNames(head(palette_ltys,   length(family_levels)), family_levels)
family_shapes = setNames(head(palette_shapes, length(family_levels)), family_levels)

# Apriori-pair styling: keep A-DECOR's color from the family plot for
# consistency; CC-DECOR takes the next palette entry.
apriori_colors = setNames(
  c(palette_colors[1], palette_colors[2]),
  apriori_levels
)
apriori_ltys   = setNames(head(palette_ltys,   length(apriori_levels)), apriori_levels)
apriori_shapes = setNames(head(palette_shapes, length(apriori_levels)), apriori_levels)

# DECOR+ heuristic mapping: DECOR+ keeps green so it matches the family plot;
# the four heuristics fill the remaining palette entries.
decorplus_colors = setNames(
  c(palette_colors[1], palette_colors[2], palette_colors[3],
    palette_colors[4], palette_colors[5]),
  decorplus_levels
)
decorplus_ltys   = setNames(palette_ltys,   decorplus_levels)
decorplus_shapes = setNames(palette_shapes, decorplus_levels)

phase_colors = c(
  "Candidates"   = palette_colors[2],
  "Verification" = palette_colors[1],
  "Total"        = palette_colors[3]
)

# Filename-safe slugs for algorithm display names.
algo_slugs = c(
  "Brute-Force"          = "naive",
  "DECOR"                = "decor",
  "DECOR+"               = "decorplus",
  "DECOR+ (SBF)"         = "smbucket",
  "DECOR+ (LGF)"         = "leastgr",
  "DECOR+ (SCSF)"        = "smCprime",
  "DECOR+ (SMCF)"        = "smC",
  "A-DECOR"              = "apriori",
  "CC-DECOR"             = "cc"
)

rename_algos = function(d) {
  d$algo[d$algo == "naive"]                                 = "Brute-Force"
  d$algo[d$algo == "decor"]                                 = "DECOR"
  d$algo[d$algo == "decorplus"]                             = "DECOR+"
  d$algo[d$algo == "decorplus_smallest_bucket"]             = "DECOR+ (SBF)"
  d$algo[d$algo == "decorplus_least_groups"]                = "DECOR+ (LGF)"
  d$algo[d$algo == "decorplus_smallest_candidate_set"]      = "DECOR+ (SCSF)"
  d$algo[d$algo == "decorplus_smallest_minimal_candidate"]  = "DECOR+ (SMCF)"
  d$algo[d$algo == "apriori"]                               = "A-DECOR"
  d$algo[d$algo == "cc"]                                    = "CC-DECOR"
  d$algo = factor(d$algo, levels = algo_levels)
  return(d)
}

open_dev = function(name, width, height) {
  if (use_tikz) {
    tikz(paste0(name, ".tex"), standAlone = FALSE, width = width, height = height)
  } else {
    pdf(file = paste0(name, ".pdf"), width = width, height = height)
  }
}

base_theme = theme_classic(base_size = 9) +
  theme(
    axis.line.x  = element_line(arrow = grid::arrow(length = unit(0.08, "cm"))),
    axis.line.y  = element_line(arrow = grid::arrow(length = unit(0.08, "cm"))),
    axis.title   = element_text(size = 8),
    axis.text    = element_text(size = 7),
    plot.title   = element_text(size = 8, hjust = 0.5, margin = margin(b = 2)),
    legend.title = element_blank(),
    legend.text  = element_text(size = 7, margin = margin(r = 6, unit = "pt")),
    legend.background  = element_rect(fill = NA),
    legend.spacing.x   = unit(0, "pt"),
    legend.spacing.y   = unit(3, "pt"),
    legend.key.height  = unit(0.5, "lines"),
    legend.key.width   = unit(0.9, "lines"),
    legend.margin      = margin(0, 0, 0, 0),
    legend.box.spacing = unit(2, "pt"),
    legend.position    = "bottom",
    plot.margin        = margin(2, 6, 1, 2)
  )

# Joint log10 y-scale (limits + every-other-power breaks) covering the union
# of `values`. Used to align the y-axis ticks of plots paired side-by-side
# in the paper. `lo_pad` reserves a small band below the lowest tick so
# bars in the phase plot have a visible baseline. `hi_pad` keeps the
# topmost tick label clear of the axis arrow.
compute_y_log_scale = function(values, lo_pad = 0.5, hi_pad = 0.5) {
  pos = values[values > 0 & is.finite(values)]
  if (length(pos) == 0) return(NULL)
  lo = floor(log10(min(pos)))
  hi = ceiling(log10(max(pos)))
  # Every second power of 10, anchored at `hi` so the topmost tick sits at
  # the data ceiling.
  break_powers = rev(seq(hi, lo, by = -2))
  list(
    limits = c(10^(lo - lo_pad), 10^(hi + hi_pad)),
    breaks = 10^break_powers
  )
}

# Build the `scale_y_log10` layer, applying `y_scale` when supplied so paired
# plots share limits and breaks (and therefore the same horizontal tick
# levels).
y_log_layer = function(y_scale) {
  if (is.null(y_scale)) {
    scale_y_log10(labels = scales::label_scientific())
  } else {
    scale_y_log10(
      limits = y_scale$limits,
      breaks = y_scale$breaks,
      expand = c(0, 0),
      labels = scales::label_scientific()
    )
  }
}

# Line plot: total runtime vs. n. Legend below the panel; multirow when needed.
plot_scaling = function(d, colors, ltys, shapes, legend_nrow = 1, y_scale = NULL) {
  ggplot(d, aes(x=n, y=mean_t, group=algo, color=algo,
                linetype=algo, shape=algo)) +
    geom_line(linewidth = 0.45) +
    geom_point(size = 1.1) +
    xlab("$n$") +
    ylab("time (ms)") +
    y_log_layer(y_scale) +
    scale_color_manual(values = colors) +
    scale_linetype_manual(values = ltys) +
    scale_shape_manual(values = shapes) +
    guides(
      color    = guide_legend(nrow = legend_nrow, byrow = TRUE),
      linetype = guide_legend(nrow = legend_nrow, byrow = TRUE),
      shape    = guide_legend(nrow = legend_nrow, byrow = TRUE)
    ) +
    base_theme
}

# Single-algorithm phase plot: three side-by-side bars per n — Candidates,
# Verification, and Total. Each bar starts at `y_floor` and ends at its own
# value, so its visible height on the log axis is `log(value / y_floor)`,
# which grows monotonically with the value it represents (independent of the
# other two). Bars whose value is at or below `y_floor` are dropped so they
# do not produce a spurious legend entry.
plot_phase_single = function(d, log_y = TRUE, y_scale = NULL) {
  d$total = d$mean_t_candidates + d$mean_t_verify

  if (log_y) {
    if (is.null(y_scale)) {
      pos = c(d$total[d$total > 0],
              d$mean_t_candidates[d$mean_t_candidates > 0],
              d$mean_t_verify[d$mean_t_verify > 0])
      y_floor = 10^(floor(log10(min(pos))) - 0.5)
    } else {
      y_floor = y_scale$limits[1]
    }
  } else {
    y_floor = 0
  }

  n_levels = sort(unique(d$n))
  d$x_idx  = match(d$n, n_levels)
  bar_w    = 0.22  # width of each of the three bars
  bar_off  = 0.28  # horizontal offset between adjacent bar centres

  # Each bar is its own filtered data slice so rows whose value is at or
  # below `y_floor` simply do not contribute a rect (avoids a spurious
  # legend entry for a phase whose bar would not be visible anyway).
  d_cand   = subset(d, mean_t_candidates > y_floor)
  d_verify = subset(d, mean_t_verify     > y_floor)
  d_total  = subset(d, total             > y_floor)

  p = ggplot() +
    geom_rect(data = d_cand,
              aes(xmin = x_idx - bar_off - bar_w / 2,
                  xmax = x_idx - bar_off + bar_w / 2,
                  ymin = y_floor, ymax = mean_t_candidates,
                  fill = "Candidates")) +
    geom_rect(data = d_verify,
              aes(xmin = x_idx - bar_w / 2,
                  xmax = x_idx + bar_w / 2,
                  ymin = y_floor, ymax = mean_t_verify,
                  fill = "Verification")) +
    geom_rect(data = d_total,
              aes(xmin = x_idx + bar_off - bar_w / 2,
                  xmax = x_idx + bar_off + bar_w / 2,
                  ymin = y_floor, ymax = total,
                  fill = "Total")) +
    scale_x_continuous(breaks = seq_along(n_levels), labels = n_levels) +
    xlab("$n$") +
    ylab("time (ms)") +
    scale_fill_manual(values = phase_colors,
                      breaks = c("Candidates", "Verification", "Total")) +
    guides(fill = guide_legend(nrow = 1)) +
    base_theme

  if (log_y) {
    if (is.null(y_scale)) {
      p = p + scale_y_log10(limits = c(y_floor, NA),
                            expand = expansion(mult = c(0, 0.05)),
                            labels = scales::label_scientific())
    } else {
      p = p + y_log_layer(y_scale)
    }
  } else {
    p = p + scale_y_continuous(expand = expansion(mult = c(0, 0.05)))
  }
  return(p)
}

# Multi-group line plot: vary one of (g, s) and hold the other fixed. Two
# such plots together (one per fixed dimension) make the 2D parameter sweep
# legible without the visual chaos of 16 dodged-bar groups in a 2.9" panel.
plot_groups_line = function(d, x_col, xlab_str, y_scale = NULL) {
  ggplot(d, aes(x = .data[[x_col]], y = mean_t, group = algo, color = algo,
                linetype = algo, shape = algo)) +
    geom_line(linewidth = 0.45) +
    geom_point(size = 1.1) +
    xlab(xlab_str) +
    ylab("time (ms)") +
    y_log_layer(y_scale) +
    scale_x_continuous(breaks = sort(unique(d[[x_col]]))) +
    scale_color_manual(values = family_colors) +
    scale_linetype_manual(values = family_ltys) +
    scale_shape_manual(values = family_shapes) +
    guides(
      color    = guide_legend(nrow = 1, byrow = TRUE),
      linetype = guide_legend(nrow = 1, byrow = TRUE),
      shape    = guide_legend(nrow = 1, byrow = TRUE)
    ) +
    base_theme
}


### Main paper ###############################################################

if (file.exists(file_main)) {
  data_main = rename_algos(read.csv(file_main, sep=",", dec="."))
  data_families = filter(data_main, algo %in% family_levels)
  data_families$algo = factor(data_families$algo, levels = family_levels)

  # Phase-decomposition data for DECOR+ — built up front so we can compute the
  # joint y-scale shared with the family-times plot it sits next to.
  d_decorplus = filter(data_families, algo == "DECOR+")

  # Pair shown side-by-side in fig:decor_revised_plot_avg: aligned y-ticks.
  y_avg_pair = compute_y_log_scale(c(
    data_families$mean_t,
    if (nrow(d_decorplus) > 0) d_decorplus$mean_t_candidates + d_decorplus$mean_t_verify else numeric()
  ))

  # Total-runtime scaling across the five algorithm families.
  open_dev("decor_revised_plot_avg_times", 2.9, 1.6)
  print(plot_scaling(data_families, family_colors, family_ltys, family_shapes,
                     legend_nrow = 1, y_scale = y_avg_pair) +
        theme(legend.justification = "left",
              legend.margin = margin(0, 0, 0, -18)))
  dev.off()

  # Phase decomposition: only DECOR+ has a non-trivial verification phase, so
  # we emit a single file for it instead of one per algorithm.
  if (nrow(d_decorplus) > 0) {
    open_dev("decor_revised_plot_avg_phases_decorplus", 2.9, 1.6)
    print(plot_phase_single(d_decorplus, y_scale = y_avg_pair))
    dev.off()
  }

  # Apriori-style comparison: A-DECOR vs CC-DECOR, averaged over k.
  d_apriori = filter(data_main, algo %in% apriori_levels)
  d_apriori$algo = factor(d_apriori$algo, levels = apriori_levels)

  # DECOR+ heuristic comparison: DECOR+ and its four bucket-selection variants.
  d_heuristics = filter(data_main, algo %in% decorplus_levels)
  d_heuristics$algo = factor(d_heuristics$algo, levels = decorplus_levels)

  # Pair shown side-by-side in fig:decor_revised_plot_apriori_heuristics.
  y_apri_heur_pair = compute_y_log_scale(c(
    if (nrow(d_apriori) > 0) d_apriori$mean_t else numeric(),
    if (nrow(d_heuristics) > 0) d_heuristics$mean_t else numeric()
  ))

  if (nrow(d_apriori) > 0) {
    open_dev("decor_revised_plot_avg_times_apriori", 2.9, 1.6)
    # Pad the bottom to match the 3-row legend of the heuristics plot so the
    # two panel heights align when set side-by-side in the paper.
    print(plot_scaling(d_apriori, apriori_colors, apriori_ltys, apriori_shapes,
                       legend_nrow = 1, y_scale = y_apri_heur_pair) +
          theme(plot.margin = margin(2, 6, 19.5, 2)))
    dev.off()
  }

  if (nrow(d_heuristics) > 0) {
    open_dev("decor_revised_plot_avg_times_heuristics", 2.9, 1.6)
    print(plot_scaling(d_heuristics, decorplus_colors, decorplus_ltys,
                       decorplus_shapes, legend_nrow = 3,
                       y_scale = y_apri_heur_pair))
    dev.off()
  }
}


### Appendix #################################################################

if (file.exists(file_app)) {
  data_app = rename_algos(read.csv(file_app, sep=",", dec="."))

  ## Single-group (g <= 1) slices by commutative proportion k ----------------
  data_single = filter(data_app, g <= 1)

  k_slices = list(
    list(label = "0",     d = filter(data_single, k == 0)),
    list(label = "2",     d = filter(data_single, k == 2)),
    list(label = "log2n", d = filter(data_single, k == floor(log2(n)))),
    list(label = "ndiv2", d = filter(data_single, k == floor(n/2))),
    list(label = "nsub1", d = filter(data_single, k == n-1)),
    list(label = "n",     d = filter(data_single, k == n))
  )

  for (slice in k_slices) {
    if (nrow(slice$d) == 0) next

    d_all = filter(slice$d, algo %in% family_levels)
    d_all$algo = factor(d_all$algo, levels = family_levels)
    d_dp  = filter(slice$d, algo == "DECOR+")

    # Joint y-scale for this k-slice pair, so the side-by-side `times` and
    # `phases_decorplus` plots have aligned y-ticks in the paper.
    y_k_pair = compute_y_log_scale(c(
      if (nrow(d_all) > 0) d_all$mean_t else numeric(),
      if (nrow(d_dp)  > 0) d_dp$mean_t_candidates + d_dp$mean_t_verify else numeric()
    ))

    # All-algorithm scaling per k.
    if (nrow(d_all) > 0) {
      open_dev(paste0("decor_revised_plot_k=", slice$label, "_times"), 2.9, 1.6)
      print(plot_scaling(d_all, family_colors, family_ltys, family_shapes,
                         legend_nrow = 1, y_scale = y_k_pair) +
            theme(legend.justification = "left",
                  legend.margin = margin(0, 0, 0, -18)))
      dev.off()
    }

    # Phase decomposition for DECOR+ at this k.
    if (nrow(d_dp) > 0) {
      open_dev(paste0("decor_revised_plot_k=", slice$label, "_phases_decorplus"), 2.9, 1.6)
      print(plot_phase_single(d_dp, y_scale = y_k_pair))
      dev.off()
    }
  }

  ## Multi-group (g >= 2): two slices through the (g, s) sweep. Fixing one of
  ## the two dimensions at its smallest value (typically 2) keeps each plot to
  ## a single 1D scan and avoids combinatorial overlap in a 2.9" panel.
  data_multi = filter(data_app, g >= 2)
  if (nrow(data_multi) > 0) {
    data_multi_fam = filter(data_multi, algo %in% family_levels)
    data_multi_fam$algo = factor(data_multi_fam$algo, levels = family_levels)

    g_fix = min(data_multi_fam$g)
    d_vs  = filter(data_multi_fam, g == g_fix)

    s_fix = min(data_multi_fam$s)
    d_vg  = filter(data_multi_fam, s == s_fix)

    # Joint y-scale for the (vary_g, vary_s) pair so their y-ticks align in
    # the paper.
    y_groups_pair = compute_y_log_scale(c(
      if (nrow(d_vs) > 0) d_vs$mean_t else numeric(),
      if (nrow(d_vg) > 0) d_vg$mean_t else numeric()
    ))

    if (nrow(d_vs) > 0) {
      open_dev("decor_revised_plot_groups_vary_s", 2.9, 1.6)
      print(plot_groups_line(d_vs, "s", "$s$", y_scale = y_groups_pair) +
            theme(legend.justification = "left",
                  legend.margin = margin(0, 0, 0, -18)))
      dev.off()
    }

    if (nrow(d_vg) > 0) {
      open_dev("decor_revised_plot_groups_vary_g", 2.9, 1.6)
      print(plot_groups_line(d_vg, "g", "$g$", y_scale = y_groups_pair) +
            theme(legend.justification = "left",
                  legend.margin = margin(0, 0, 0, -18)))
      dev.off()
    }
  }
}
