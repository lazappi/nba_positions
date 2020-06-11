library(tidyverse)

# Seasons_Stats.csv can be downloaded from
# https://www.kaggle.com/drgilermo/nba-players-stats/data?select=Seasons_Stats.csv

# Read dataset
seasons_stats <- read_csv("Seasons_Stats.csv", col_types= cols(
    .default = col_double(),
    Player   = col_character(),
    Pos      = col_character(),
    Tm       = col_character())
)

nba_positions_full <- seasons_stats %>%
    # Select players in 2017
    filter(Year == 2017) %>%
    # Select stats we want to keep
    select(
        Player,
        Team         = Tm,
        Games        = G,
        Position     = Pos,
        TurnoverPct  = `TOV%`,
        ReboundPct   = `TRB%`,
        AssistPct    = `AST%`,
        FieldGoalPct =`FG%`
    ) %>%
    # Make FieldGoalPct in range 0-100 to match others
    mutate(FieldGoalPct = FieldGoalPct * 100) %>%
    # Rename positions
    mutate(
        Position = fct_recode(
            Position,
            Center              = "C",
            PowerForward        = "PF",
            PowerForward_Center = "PF-C",
            PointGuard          = "PG",
            SmallForward        = "SF",
            ShootingGuard       = "SG"
        )
    )

nba_positions <- nba_positions_full %>%
    # Summarise players regardless of team
    group_by(Player, Position) %>%
    summarise(
        Games        = sum(Games),
        TurnoverPct  = mean(TurnoverPct),
        ReboundPct   = mean(ReboundPct),
        AssistPct    = mean(AssistPct),
        FieldGoalPct = mean(FieldGoalPct)
    ) %>%
    ungroup() %>%
    # Select only Centers, Points Guards and Shooting Guards
    # with at least 10 games
    filter(
        Position %in% c("Center", "PointGuard", "ShootingGuard"),
        Games > 10
    ) %>%
    # Remove missing data and unneeded columns
    drop_na() %>%
    select(-Player, -Games)

# Create a matrix with just the stat values
stats_matrix <- as.matrix(nba_positions[2:5])

# Group players using k-means with 3 clusters
k_means <- kmeans(stats_matrix, 3, iter.max = 100, nstart = 1000)

# Find the cluster containing Centers
center_cluster <- names(
    sort(
        table(k_means$cluster[nba_positions$Position == "Center"]),
        decreasing = TRUE
    )[1]
)

# Find the distance of each player from their respective cluster centre
dists_from_centre <- sqrt(rowSums(stats_matrix - fitted(k_means)) ^ 2)

set.seed(1)
nba_positions <- nba_positions %>%
    # Add cluster and distance from centre to players
    mutate(
        Cluster = k_means$cluster,
        Dist    = dists_from_centre
    ) %>%
    # Select only Centers in the Center cluster and
    # Guards NOT in the Center cluster
    filter(
        (Cluster == center_cluster & Position == "Center") |
            (Cluster != center_cluster & Position != "Center")
    )

# Select 50 Centers closest to the center of that cluster
centers <- nba_positions %>%
    filter(Position == "Center") %>%
    slice_min(Dist, n = 50)

# Select 50 Point Guards and 50 Shooting Guards
guards <- nba_positions %>%
    filter(Position != "Center") %>%
    group_by(Position) %>%
    slice_sample(n = 50) %>%
    ungroup()

# Combine the selected players
nba_positions <- centers %>%
    bind_rows(guards) %>%
    arrange(Position) %>%
    # Remove unneeded columns
    select(-Cluster, -Dist)

write_tsv(nba_positions_full, "nba_positions_full.tsv")
write_tsv(nba_positions, "nba_positions.tsv")
