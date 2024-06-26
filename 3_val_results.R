# Contrasting simulated vs observed  ----

library(tidyverse)
library(rCTOOL)
library(ggpmisc)
library(ggpubr)
library(meta)

# set aesthetics

theme_set(theme_bw())
theme_update(panel.grid = element_blank())


colors_sr = c("0" ="#E54E21", "4" = "#ff950e", "8"="#0A9F9D", "12"="#273046")

# merge observed and simulated data

compare_plot <- merge(plot_results_oct #_juan#_dec,
                      ,scn_plot_year,
                      by = 'plotyear', all.x = TRUE) |>
  select(!contains(".y"))

names(compare_plot) <- sub(".x", "", names(compare_plot))

compare_plot <- compare_plot |>
  mutate(Straw_Rate_treat =
           recode(Sample_ID,
                  "201" = "0","606" = "0","708" = "0",
                  "208" = "4","301" = "4","706" = "4",
                  "206" = "8","308" = "8","601" = "8",
                  "608" = "12","306" = "12","701" = "12"
           )) |>
  mutate(Straw_Rate_treat =
           fct_relevel(Straw_Rate_treat, c("0", "4", "8", "12"))
  )

compare_plot |>
  ggplot(aes(y=C_topsoil, x=yrs, col=Straw_Rate_treat))+
  geom_point()+
  scale_x_continuous(breaks=unique(compare_plot$yrs))+
  geom_point(aes(y=Topsoil_C_obs,  col=Straw_Rate_treat),
             shape=17, size=2)+
  scale_y_continuous(sec.axis = sec_axis(~.#, name = "Observed"
                                         #breaks =seq(40,180,20),
  ))+
  labs(y="Topsoil Total C [Mg/ha m]",x= "year")+
  theme(panel.background = NULL, text = element_text(size=16),
        axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1))+
  scale_color_manual("Straw Rate Treatmnet",
                     values = colors_sr)

# # Scatter val ----
scatter_lte <-
  compare_plot |> filter(Allo=="Fixed") |>
  group_by(year, Straw_Rate_treat) |>
  mutate(mean = mean(Topsoil_C_obs, na.rm=TRUE),
         sd = sd(Topsoil_C_obs, na.rm=TRUE) #/sqrt(n())
  ) |>
  ungroup() |>
  ggplot(aes(y = mean,
             x = as.numeric(year),
             col = Straw_Rate_treat)
  ) +
  scale_x_continuous(breaks = c(1951,
                                as.vector(as.numeric(unique(soil_plots$year)))),
                     minor_breaks = NULL, limits = c(1951,2020)) +
  scale_y_continuous(breaks = seq(40,70,5),minor_breaks = NULL)+
  geom_point() +
  geom_errorbar(aes(ymin = mean - sd, ymax = mean + sd), width = 0.4)+
  labs(y = "Topsoil C Observed (Mg/ha)", x = "Year") +

  scale_color_manual("Straw Rate Treatment",
                     values = colors_sr) +
  geom_line(aes(y = C_topsoil,
                x = year,
                #group = interaction(Allo, Straw_Rate_treat),
                col = (Straw_Rate_treat)#,
                #linetype = Allo
  )) +
  # geom_point(aes(y = C_topsoil,
  #                x = year,
  #                #group = interaction(Allo, Straw_Rate_treat),
  #                col = (Straw_Rate_treat)
  # ), alpha = 0.1)+
  #scale_linetype_discrete("C Input Estimation")+
  theme_bw()+theme(text = element_text(size = 11),
                   axis.text.x = element_text(angle = 90, hjust = -0.2,
                                              size = 9),
                   legend.position = "bottom")

scatter_lte


ggsave(plot=scatter_lte,
       filename = "fig_tabl/scatter2col.jpeg",
       width=182,
       height=182/2,
       units = c("mm"),
       dpi = 300)

# Correlation ----
corr_block <-
  compare_plot |> filter(Allo=="Fixed") |>
  mutate(block_facet=paste("Block:",Block, sep = " ")) |>
  ggplot(aes(x = C_topsoil, y = Topsoil_C_obs)) +
  stat_poly_line(se=FALSE,color="#505050") +
  stat_cor(p.accuracy = 0.001, r.accuracy = 0.01) +
  geom_point(aes(col = Straw_Rate_treat)) +
  scale_y_continuous(breaks = seq(40,70,10),minor_breaks = NULL)+
  scale_x_continuous(breaks = seq(40,70,10),minor_breaks = NULL)+
  facet_grid(.~ block_facet) +
  geom_abline(intercept = 0, slope = 1) +
  labs(y = "SOC Observed (Mg/ha)", x = "SOC Simulated by rCTOOL (Mg/ha)") +
  scale_color_manual("Straw Rate Treatment",
                     values = colors_sr)+
  theme(text = element_text(size = 11),
        legend.position = "bottom")

corr_block

ggsave(plot=corr_block,
       filename = "fig_tabl/corr_block2col.jpeg",
       width=182,
       height=182/2,
       units = c("mm"),
       dpi = 300)

compare_plot |>
  drop_na(Topsoil_C_obs)|>
  mutate(res=C_topsoil-Topsoil_C_obs) |>
  group_by(Allo#, Straw_Rate ,Block
  ) |>
  summarise(
    RMSE = sqrt(mean((res)^2)),
    RMSE_rel=sqrt(mean((res)^2))/mean(Topsoil_C_obs,na.rm=TRUE)*100)


ggsave(ggarrange(scatter_lte,corr_block,
                 ncol=1,#nrow = 2,
                 common.legend = TRUE,
                 labels = c("a", "b"),
                 legend=c("bottom")),
       filename = "fig_tabl/compose2.jpeg",
       width=186,
       #height=182,
       units = c("mm"),
       dpi = 300)

# Forest plot block----

merge_meta_dep <- compare_plot |> drop_na(Topsoil_C_obs) |>
  filter(Allo=="Fixed") |> unique() |>
  group_by(Block ,Straw_Rate_treat #year#,
  ) |>
  summarise(
    mean_obs=mean(Topsoil_C_obs),
    mean_sim=mean(C_topsoil),

    sd_obs=sd(Topsoil_C_obs),
    sd_sim=sd(C_topsoil),

    se_obs=sd(Topsoil_C_obs)/sqrt(n()),
    se_sim=sd(C_topsoil)/sqrt(n()),

    cv_obs=sd(Topsoil_C_obs)/mean(Topsoil_C_obs)*100,
    cv_sim=sd(C_topsoil)/mean(C_topsoil)*100,


    n_obs=n(),
    n_sim=n()

  ) |> unique()
#filter(Allo=="PartFixedSt") #|>
#mutate(
#'Block & C Input Estimation'= interaction(Block, Allo)
#)

#### Mean differences by  straw rate levels incorporating a Block random effect ----
mm <- metacont(n_obs, mean_obs, sd_obs,
               n_sim, mean_sim,sd_sim,

               studlab=paste(Straw_Rate_treat
                             #,year
                             #,Allo
                             #,Block
               ),
               data=merge_meta_dep,
               comb.fixed= FALSE,
               comb.random = TRUE,
               sm = "MD",
               hakn = TRUE,
               method.tau = "REML",
               byvar = Block #`Block & C Input Estimation`
)


forest(mm,
       layout = "RevMan5",#"JAMA"
       digits = 2,
       digits.sd = 2,
       print.tau2 = gs("forest.tau2"),
       digits.tau2 = 2,
       col.by = "#505050",
       label.c="Simulated",
       label.e="Observed",
       type.random="diamond",
       type.subgroup = "circle",
       type.study = "circle",
       #type.common = "square",
       colgap = "0.5cm",
       colgap.forest = "0.5cm",
       col.circle = "#9e5d52",
       col.circle.lines = "black",
       col.diamond.random = "black",
       fontsize = 11
       # fs.study = 10,
       # fs.random = 10,
       # fs.random.labels = 10,
       # fs.study.labels = 10,
       # fs.test.subgroup = 10,
       # fs.common.labels = 12,
       # fs.heading = 12
       )

# Forest plot year----

merge_meta_dep <- compare_plot |> drop_na(Topsoil_C_obs) |>
  filter(Allo=="Fixed") |> unique() |>
  group_by( year,Block #,Straw_Rate_treat,
  ) |>
  summarise(
    mean_obs=mean(Topsoil_C_obs),
    mean_sim=mean(C_topsoil),

    sd_obs=sd(Topsoil_C_obs),
    sd_sim=sd(C_topsoil),

    se_obs=sd(Topsoil_C_obs)/sqrt(n()),
    se_sim=sd(C_topsoil)/sqrt(n()),

    cv_obs=sd(Topsoil_C_obs)/mean(Topsoil_C_obs)*100,
    cv_sim=sd(C_topsoil)/mean(C_topsoil)*100,


    n_obs=n(),
    n_sim=n()

  ) |> unique()
#filter(Allo=="PartFixedSt") #|>
#mutate(
#'Block & C Input Estimation'= interaction(Block, Allo)
#)

#### Mean differences by  straw rate levels incorporating a Block random effect ----
mm_y <- metacont(n_obs, mean_obs, sd_obs,
               n_sim, mean_sim,sd_sim,

               studlab=paste(#Straw_Rate_treat
                             #,
                 year
                             #,Allo
                             #,Block
               ),
               data=merge_meta_dep,
               comb.fixed= FALSE,
               comb.random = TRUE,
               sm = "MD",
               hakn = TRUE,
               method.tau = "REML",
               byvar = Block #`Block & C Input Estimation`
)


forest(mm_y,
       layout = "RevMan5",#"JAMA"
       digits = 2,
       digits.sd = 2,
       print.tau2 = gs("forest.tau2"),
       digits.tau2 = 2,
       col.by = "#505050",
       label.c="Simulated",
       label.e="Observed",
       type.random="diamond",
       type.subgroup = "circle",
       type.study = "circle",
       type.common = "square",
       colgap = "0.5cm",
       colgap.forest = "0.5cm",
       col.circle = "#9e5d52",
       col.circle.lines = "black",
       col.diamond.random = "black",
       fontsize = 10,
       spacing = .8
       # fs.study = 10,
       # fs.random = 10,
       # fs.random.labels = 10,
       # fs.study.labels = 10,
       # fs.test.subgroup = 10,
       # fs.common.labels = 12,
       # fs.heading = 12
)




# Residual variance component analyisis ----

compare_plot$resid <- compare_plot$Topsoil_C_obs-compare_plot$C_topsoil

library(lme4)

res_VCA<-lme4::lmer(
  resid~1+
    (1|year)+
    #(1|Allo)+
    (1|Block)
  ,na.action=na.omit
  ,REML=T
  ,data=compare_plot)

summary(res_VCA)

vca <- as.data.frame(VarCorr(res_VCA))

vca |> group_by(grp) |> summarise(
  varprop = vcov / sum(vca$vcov) * 100) |> arrange(
    varprop, grp) #|>
  #ggplot(aes(y=varprop, x=1, fill=grp))+
  #geom_bar(stat="identity")+
  #theme_bw()


