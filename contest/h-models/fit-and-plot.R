library(courtsports)
library(tidyverse)
library(broom)
library(lme4)

## Define theme and colors

my_theme <-  theme_bw() + # White background, black and white theme
  theme(axis.text = element_text(size = 12),
        text = element_text(size = 14,
                            family="serif"),
        plot.title = element_text(hjust = 0.5, size=16))

win_colors <- c("#336699", "#339966")

tournament_colors <- c("#0297DB", "#b06835", "#ffe500", "#54008b")

## Define variables for modeling
gs_players$name_int = as.integer(as.factor(gs_players$name))
gs_players$name_fac = as.factor(gs_players$name)
gs_players$hand_fac = as.factor(gs_players$hand)
gs_players$ioc_fac = as.factor(gs_players$ioc)
gs_players$atp = gs_players$league == "ATP"
gs_players$year_fac = as.factor(gs_players$year)
gs_players$late_round = gs_players$round >= "R16"
gs_players$seeded = gs_players$rank <= 32
gs_players$opponent_seeded = gs_players$opponent_rank <= 32

gs_partial_players$name_int = as.integer(as.factor(gs_partial_players$name))
gs_partial_players$name_fac = as.factor(gs_partial_players$name)
gs_partial_players$ioc_fac = as.factor(gs_partial_players$ioc)
gs_partial_players$atp = gs_partial_players$Tour == "atp"
gs_partial_players$year_fac = as.factor(gs_partial_players$year)
gs_partial_players$late_round = gs_partial_players$round >= "R16"
gs_partial_players$seeded = gs_partial_players$rank <= 32
gs_partial_players$opponent_seeded = gs_partial_players$opponent_rank <= 32

## Fit models used in paper
set.seed(091418)
ind_logistic_noioc = lme4::glmer(did_win ~ late_round + log(rank) + log(opponent_rank) + year_fac + atp + (0 + tournament |name_int), data = gs_players, family = "binomial", nAGQ =0)
n_aces_mod = lme4::lmer(n_aces ~ late_round + log(rank) + log(opponent_rank) + year_fac + atp + (0 + tournament |name_fac), data = gs_partial_players)
n_winners_mod = lme4::lmer(n_winners ~ late_round + log(rank) + log(opponent_rank) + year_fac + atp + (0 + tournament |name_fac), data = gs_partial_players)
n_net_mod = lme4::lmer(n_netpt_w ~ late_round + log(rank) + log(opponent_rank) + year_fac + atp + (0 + tournament |name_fac), data = gs_partial_players)
n_ue_mod = lmer(n_ue ~ late_round + log(rank) + log(opponent_rank) + year_fac + atp + (0 + tournament |name_fac), data = gs_partial_players)


model_names = c("nocourt_logistic", "base_logistic", "country_logistic", "ind_logistic",
                "ind_logistic_noioc", "ind_int_logistic", "ind_year_logistic")

model.sums = data.frame(model = model_names, aic = rep(NA, length(model_names)), edf = rep(NA,length(model_names)))
model.ests = data.frame()
ran.effects = data.frame()
for(mod in 1:nrow(model.sums)){
  name = model_names[mod]
  model.sums$aic[mod] = extractAIC(get(name))[2]
  model.sums$edf[mod] = extractAIC(get(name))[1]
  betas = tidy(get(name))
  betas$model = name
  if("group" %in% colnames(betas)){
    model.ests = rbind(model.ests, filter(betas, group == "fixed") %>%
                         dplyr::select(., -c("group")))
  }
  else model.ests = rbind(model.ests, betas)
}

model.sums$name = c("no_court", "no_random_ef", "country_ef", "ind_ef", "ind_no_ioc", "ind_intercept", "ind_year_ef")
model.sums$fixed = c("No country, no tournament",
                     "all",
                     "no country, no tournament",
                     "no tournament",
                     "no country, no tournament",
                     "no country",
                     "no country, no year")
model.sums$random = c("none",
                      "none",
                      "tournament (by country)",
                      "tournament (by individual)",
                      "tournament (by individual)",
                      "intercept (by individual)",
                      "year (by individual)")

## Plots for "wins" model
fixed.effects.plot = model.ests %>%
  filter(., !grepl("ioc", term)) %>%
  filter(., model == 'ind_logistic_noioc') %>%
  ggplot(., aes(x = term, y = estimate, col = model, ymin = estimate - 2*std.error, ymax = estimate + 2*std.error)) +
  geom_errorbar(width = .7, position = position_dodge(), size = 1.5) +
  my_theme +
  # coord_flip() +
  theme(axis.text.x=element_text(angle = 35, hjust = 1)) +
  ggtitle("Fixed effects") +
  scale_color_brewer("",palette = "Dark2") +
  theme(legend.position = "none") +
  xlab("") +
  ylab("Coefficient") +
  scale_x_discrete("", breaks = waiver(), labels = c("Intercept", "ATP", "Late round", "Op Rank (log)", "Rank (log)", "2014", "2015", "2016", "2017"))+
  guides(col = guide_legend(nrow=2)) +
  geom_hline(yintercept = 0, color = "grey") +
  theme(panel.grid.major = element_blank(),
        panel.grid.minor = element_blank())

ran_tourn = rbind(ranef(ind_logistic)$name_int, ranef(ind_logistic_noioc)$name_int)
ran_tourn$model = c(rep("ind_logistic", nrow(ranef(ind_logistic)$name_int)), rep("ind_logistic_noioc", nrow(ranef(ind_logistic)$name_int)))

name_lookup = unique(cbind(gs_players$name, gs_players$name_int))
name_lookup = name_lookup[order(as.integer(name_lookup[,2])),]

top_three_ranef = as.data.frame(ranef(ind_logistic_noioc, condVar = TRUE)) %>%
  mutate(tournament = gsub("tournament", "", term)) %>%
  mutate(name = name_lookup[,1][as.integer(grp)]) %>%
  filter(., name == "Serena Williams" | name == "Rafael Nadal" | name == "Roger Federer") %>%
  ggplot(., aes(x = name, y = condval, ymin = condval- 2*condsd, ymax = condval + 2*condsd, color = tournament)) +
  geom_errorbar(width = .5, position = "dodge",size = 1.5) +
  xlab("") +
  ylab("Coefficient") +
  scale_color_manual("", values=tournament_colors) +
  my_theme +
  coord_flip() +
  ggtitle("Random Effects") +
  theme(legend.position = "bottom") +
  guides(col = guide_legend(nrow=2,
                            override.aes = list(size = 7))) +
  geom_hline(yintercept = 0, color = "grey") +
  theme(panel.grid.major = element_blank(),
        panel.grid.minor = element_blank())

grid.arrange(fixed.effects.plot, top_three_ranef, nrow = 1, widths = c(.45, .55) #,
             # top = textGrob("Parameter estimates from logistic model",
             #                gp=gpar(fontsize=20, fontfamily="serif"))
)

top_three_ranef = as.data.frame(ranef(ind_logistic_noioc, condVar = TRUE)) %>%
  mutate(tournament = gsub("tournament", "", term)) %>%
  mutate(name = name_lookup[,1][as.integer(grp)]) %>%
  filter(., name == "Serena Williams" | name == "Rafael Nadal" | name == "Roger Federer") %>%
  ggplot(., aes(x = name, y = condval, ymin = condval- 2*condsd, ymax = condval + 2*condsd, color = tournament)) +
  geom_errorbar(width = .5, position = "dodge",size = 1.5) +
  xlab("") +
  ylab("Coefficient") +
  scale_color_manual("", values=tournament_colors) +
  my_theme +
  coord_flip() +
  ggtitle("Random Effects") +
  theme(legend.position = "bottom") +
  guides(col = guide_legend(nrow=2,
                            override.aes = list(size = 7))) +
  geom_hline(yintercept = 0, color = "grey") +
  theme(panel.grid.major = element_blank(),
        panel.grid.minor = element_blank())

largest_effects = as.data.frame(ranef(iln_fast_fac, condVar = TRUE)) %>%
  mutate(tournament = gsub("tournament", "", term)) %>%
  mutate(name = name_lookup[,1][as.integer(grp)]) %>%
  filter(condval - 2*condsd > 0 | condval + 2*condsd < 0) %>%
  ggplot(., aes(x = name, y = condval, ymin = condval- 2*condsd, ymax = condval + 2*condsd, color = tournament)) +
  geom_errorbar(width = .5, position = "dodge",size = 1.5) +
  xlab("") +
  ylab("Coefficient") +
  scale_color_manual("", values=tournament_colors) +
  my_theme +
  coord_flip() +
  ggtitle("Random Effects") +
  theme(legend.position = "bottom") +
  guides(col = guide_legend(nrow=2,
                            override.aes = list(size = 7))) +
  geom_hline(yintercept = 0, color = "grey") +
  theme(panel.grid.major = element_blank(),
        panel.grid.minor = element_blank())

gs_players %>%
  filter(name == "Serena Williams") %>%
  select(year, tournament, rank, opponent_rank, did_win) %>% View()


win_colors <- c("#336699", "#339966")

mat <-

colnames(mat) <- c("Aus. Open", "French Open", "US Open", "Wimbledon")
rownames(mat) <- c("Aus. Open", "French Open", "US Open", "Wimbledon")
#
df <- melt(mat)
#
attr(VarCorr(ind_logistic_noioc)$name_int, "correlation") %>%
  tbl_df %>%
  transmute(
    `Aus. Open` = `tournamentAustralian Open`,
    `French Open` = `tournamentFrench Open`,
    `US Open` = `tournamentUS Open`,
    `Wimbledon` = `tournamentWimbledon`,
    Var2 = c("Aus. Open", "French Open", "US Open", "Wimbledon")
  ) %>%
  pivot_longer(-c(Var2), names_to = "Var1", values_to = "value") %>%
  ggplot(aes(x = Var1, y = Var2, fill = value)) +
  geom_tile() +
  geom_tile(color = "white")+
  scale_fill_gradient2(low = win_colors[2], high = win_colors[1], mid = "white",
                       midpoint = 0, limit = c(-1,1),
                       space = "Lab", name="Correlation") +
  # labels = c("-1.0", "-0.5", "  0.0", "  0.5", "  1.0")) +
  labs(x = "", y = "",
       title = "Correlation matrix for random effects")  +
  my_theme


aces_ranef = as.data.frame(ranef(n_aces_mod, condVar = TRUE)) %>%
  mutate(tournament = gsub("tournament", "", term)) %>%
  filter(., grp == "Serena Williams" | grp == "Rafael Nadal" | grp == "Roger Federer") %>%
  ggplot(., aes(x = as.character(grp), y = condval, ymin = condval- 2*condsd, ymax = condval + 2*condsd, col = tournament)) +
  geom_errorbar(height = .5, position = position_dodge(), size = 1.5) +
  ylab("Estimate") +
  xlab("") +
  ggtitle("Aces") +
  scale_color_manual("", values=tournament_colors) +
  my_theme +
  coord_flip() +
  theme(legend.position = "none")

nets_ranef = as.data.frame(ranef(n_net_mod, condVar = TRUE)) %>%
  mutate(tournament = gsub("tournament", "", term)) %>%
  filter(., grp == "Serena Williams" | grp == "Rafael Nadal" | grp == "Roger Federer") %>%
  ggplot(., aes(x = as.character(grp), y = condval, ymin = condval- 2*condsd, ymax = condval + 2*condsd, col = tournament)) +
  geom_errorbar(height = .5, position = position_dodge(), size = 1.5) +
  ylab("Estimate") +
  xlab("") +
  ggtitle("Net Wins") +
  scale_color_manual("", values=tournament_colors) +
  my_theme +
  theme(axis.text.y = element_blank()) +
  coord_flip()  +
  theme(legend.position = "none")

ue_ranef = as.data.frame(ranef(n_ue_mod, condVar = TRUE)) %>%
  mutate(tournament = gsub("tournament", "", term)) %>%
  filter(., grp == "Serena Williams" | grp == "Rafael Nadal" | grp == "Roger Federer") %>%
  ggplot(., aes(x = as.character(grp), y = condval, ymin = condval- 2*condsd, ymax = condval + 2*condsd, col = tournament)) +
  geom_errorbar(height = .5, position = position_dodge(), size = 1.5) +
  ylab("Estimate") +
  xlab("") +
  ggtitle("Unforced Errors") +
  scale_color_manual("", values=tournament_colors) +
  my_theme +
  theme(axis.text.y = element_blank()) +
  coord_flip() +
  theme(legend.text=element_text(size=10))

ggpubr::ggarrange(aces_ranef, nets_ranef, ue_ranef,
                  nrow =1,
                  ncol = 3,
                  common.legend = TRUE,
                  legend="bottom",
                  widths = c(.45, .27, .27))

ggplot(data.frame(eta=predict(n_net_mod,type="link"),pearson=residuals(n_net_mod,type="pearson")),
       aes(x=eta,y=pearson)) +
  geom_point() +
  theme_bw()

qqnorm(residuals(n_net_mod))
qqnorm(residuals(n_aces_mod))
qqnorm(residuals(n_ue_mod))

more_players = c(
  "Roger Federer",
  "Andy Murray",
  "David Ferrer",
  "Fernando Verdasco",
  "Grigor Dimitrov",
  "Kei Nishikori",
  "Kevin Anderson",
  "Marin Cilic",
  "Nick Kyrgios",
  "Novak Djokovic",
  "Rafael Nadal",
  "Roberto Bautista Agut",
  "Sam Querrey",
  "Agnieszka Radwanska",
  "Angelique Kerber",
  "Petra Kvitova",
  "Serena Williams",
  "Venus Williams",
  "Victoria Azarenka"
)

as.data.frame(ranef(n_ue_mod, condVar = TRUE)) %>%
  mutate(tournament = gsub("tournament", "", term)) %>%
  filter(grp %in% more_players) %>%
  ggplot(., aes(x = grp, y = condval, ymin = condval- 2*condsd, ymax = condval + 2*condsd, color = tournament)) +
  geom_errorbar(width = .5, position = "dodge",size = 1.5) +
  xlab("") +
  ylab("Coefficient") +
  scale_color_manual("", values=tournament_colors) +
  my_theme +
  coord_flip() +
  ggtitle("Unforced Errors \n Random Player Effect") +
  theme(legend.position = "bottom") +
  guides(col = guide_legend(nrow=2,
                            override.aes = list(size = 7))) +
  geom_hline(yintercept = 0, color = "grey") +
  theme(panel.grid.major = element_blank(),
        panel.grid.minor = element_blank())

as.data.frame(ranef(n_aces_mod, condVar = TRUE)) %>%
  mutate(tournament = gsub("tournament", "", term)) %>%
  filter(grp %in% more_players) %>%
  ggplot(., aes(x = grp, y = condval, ymin = condval- 2*condsd, ymax = condval + 2*condsd, color = tournament)) +
  geom_errorbar(width = .5, position = "dodge",size = 1.5) +
  xlab("") +
  ylab("Coefficient") +
  scale_color_manual("", values=tournament_colors) +
  my_theme +
  coord_flip() +
  ggtitle("Aces \n Random Player Effect") +
  theme(legend.position = "bottom") +
  guides(col = guide_legend(nrow=2,
                            override.aes = list(size = 7))) +
  geom_hline(yintercept = 0, color = "grey") +
  theme(panel.grid.major = element_blank(),
        panel.grid.minor = element_blank())

as.data.frame(ranef(n_net_mod, condVar = TRUE)) %>%
  mutate(tournament = gsub("tournament", "", term)) %>%
  filter(grp %in% more_players) %>%
  ggplot(., aes(x = grp, y = condval, ymin = condval- 2*condsd, ymax = condval + 2*condsd, color = tournament)) +
  geom_errorbar(width = .5, position = "dodge",size = 1.5) +
  xlab("") +
  ylab("Coefficient") +
  scale_color_manual("", values=tournament_colors) +
  my_theme +
  coord_flip() +
  ggtitle("Points won at net \n Random Player Effect") +
  theme(legend.position = "bottom") +
  guides(col = guide_legend(nrow=2,
                            override.aes = list(size = 7))) +
  geom_hline(yintercept = 0, color = "grey") +
  theme(panel.grid.major = element_blank(),
        panel.grid.minor = element_blank())
