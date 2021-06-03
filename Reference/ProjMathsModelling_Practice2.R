setwd("/Users/fanahanmcsweeney/Projects/STAT40620-R-Project")

# set folder path (file is saved in "Data" folder where markdown file is saved)
folderpath = paste(getwd(), "/Data",sep="")

# create function to merge files into a single data frame
mergeFiles = function(mypath){
  # merge files starting with the string "season-" (in case other files are in the data folder) 
  filenames = list.files(path = mypath, full.names = TRUE, pattern = "season-")
  
  # read each csv file and save in a list
  datalist = lapply(filenames,
                    function(x){read.csv(file = x, header = TRUE, stringsAsFactors = FALSE)})
  # sequentially apply merge function to each element of our list to create a single data 
  Reduce(function(x,y) {merge(x, y, all = TRUE, sort=FALSE)}, datalist)
}


# call mergeFiles function to create data frame of all csv files
EPL_raw <- mergeFiles(folderpath)

# drop unwanted columns
EPL <- EPL_raw[,c("HomeTeam", "AwayTeam", "FTR")]
# add new columns to store % of total points obtained that season obtained by the home and away teams
EPL$HomePPC <- 0
EPL$AwayPPC <- 0

# print column names
names(EPL)
dim(EPL)

num_seasons <- 10
games_per_season <- 380
start_ind <- 1
end_ind <- 380

teams_WLD_list <- vector("list", length=num_seasons)

for (season in 1:num_seasons) {
  # get vector of all teams in the current season
  teams <- NULL
  teams <- unique(EPL$HomeTeam[start_ind:end_ind])

  # create empty matrix to store stats for each team for the current season
  teams_WLD <- matrix(NA, length(teams), 5)
  # rename rows and columns
  colnames(teams_WLD) <- c("W", "D", "L", "Points", "Points%")
  rownames(teams_WLD) <- teams
  
  # Calculate number of wins/losses/draws/points and % of total possible points achieved by each team
  for (team in teams) {
    Ws <- sum((EPL[start_ind:end_ind,"HomeTeam"]==team & EPL[start_ind:end_ind,"FTR"]=="H") | (EPL[start_ind:end_ind,"AwayTeam"]==team & EPL[start_ind:end_ind,"FTR"]=="A"))
    Ds <- sum((EPL[start_ind:end_ind,"HomeTeam"]==team | EPL[start_ind:end_ind,"AwayTeam"]==team) & EPL[start_ind:end_ind,"FTR"]=="D")
    Ls <- sum((EPL[start_ind:end_ind,"HomeTeam"]==team & EPL[start_ind:end_ind,"FTR"]=="A") | (EPL[start_ind:end_ind,"AwayTeam"]==team & EPL[start_ind:end_ind,"FTR"]=="H"))
    Ps <- 3*Ws + 1*Ds
    PsPC <- Ps/(sum(Ws+Ds+Ls)*3)
    
    # get row index of currently selected team, add current values to that row
    ind <- which(rownames(teams_WLD)==team)
    teams_WLD[ind,] <- c(Ws, Ds, Ls, Ps, PsPC)
  }
  
  # add % of total points for current row home and away teams to the corresponding columns
  for (i in start_ind:end_ind) {
    H_ind <- which(rownames(teams_WLD)==EPL$HomeTeam[i])
    A_ind <- which(rownames(teams_WLD)==EPL$AwayTeam[i])
    
    EPL$HomePPC[i] <- teams_WLD[H_ind,"Points%"]
    EPL$AwayPPC[i] <- teams_WLD[A_ind,"Points%"]
  }
  
  # add current season data to the the global list
  teams_WLD_list[[season]] <- teams_WLD[order(teams_WLD[,"Points%"], decreasing = T),]
  # add 380 to start/end index values for the next season
  start_ind <- start_ind + games_per_season
  end_ind <- end_ind + games_per_season
}

EPL$FTR <- as.factor(EPL$FTR)

head(EPL)
EPL$HomePPC[370:390]

# boxplot of difference in % total points between home and away teams, separated by result
boxplot((EPL$HomePPC-EPL$AwayPPC)~EPL$FTR, main="", 
        xlab="Result", ylab="Difference in Proportion of Total Points (Home vs Away)")

# print list of all final standings tables for the past 10 seasons
teams_WLD_list




# classification of WDA
library(randomForest)

# function to calculate classification accuracy
class_acc <- function(y, yhat) {
  tab <- table(y, yhat)
  return(sum(diag(tab))/sum(tab) )
}

df <- EPL[,c("HomePPC", "AwayPPC", "FTR")]
# set aside test data
N <- nrow(df)
# set seed for reproducibility
set.seed(123)
# reserve 20% of the observations for testing
test <- sample(1:N, N*0.3)
# create x vector and y matrix for test set 
df_test <- df[test,]
x_t <- subset(df, select = -FTR)
y_t <- df$FTR[test]

# select remaining data for training and validation
train <- setdiff(1:N, test)
df_train <- df[train,]

# fit random forest model with training data
fit_rf <- randomForest(FTR ~ HomePPC+AwayPPC, data = df_train, ntree=500)
# predict classes of test set
pred_test <- predict(fit_rf, newdata=df_test, type="class")
pred_train <- predict(fit_rf, type = "class")
pred_prob <- predict(fit_rf, newdata=df_test, type="prob")
pred_all <- predict(fit_rf, newdata=df, type = "class")

# calculate classification accuracy of the training data
class_acc(pred_train, df_train$FTR)
table(pred_train, df_train$FTR)
# ...and on the test data
class_acc(pred_test, df_test$FTR)
table(pred_test, df_test$FTR)

pred_prob[1:10,]

# predict probabilities for all fixtures
pred_prob_all <- predict(fit_rf, newdata=df, type="prob")

# print table of % of total results that ended "A", "D" and "H"
table(df$FTR)/nrow(pred_prob_all)
# print mean values of predicted probabilities for each result type ("A", "D" and "H")
colMeans(pred_prob_all)


# create emoty vector
rrr <- rep(0, nrow(df))
# for each fixture, sample the result using predicted probabilities
for(i in 1:nrow(pred_prob_all)) {
  rrr[i] <- sample(c("A", "D", "H"), 1, prob = pred_prob_all[i,])
}

# plot table of fixture result that was sampled
table(rrr)
# print table of actual results for the same fixtures
table(df$FTR)


# testing prediction of a single new observation
newprobs <- cbind(0.5, 0.5)
newprobs <- data.frame(newprobs)
colnames(newprobs) <- c("HomePPC", "AwayPPC")
predict(fit_rf, newdata=newprobs, type="prob")






num_seasons <- 10
games_per_season <- 380
start_ind <- 1
end_ind <- 380

WLD_prog_list <- vector("list", length=num_seasons)

for (season in 1:num_seasons) {
  # get vector of all teams in the current season
  teams <- NULL
  teams <- unique(EPL$HomeTeam[start_ind:end_ind])

  # create empty matrix to store stats for each team for the current season
  WLD_prog <- matrix(NA, length(teams), 38)
  # rename rows and columns
  colnames(WLD_prog) <- 1:38
  rownames(WLD_prog) <- teams

  
  for(game in start_ind:end_ind) {
    # get names of home and away teams for the current fixture
    Home <- EPL$HomeTeam[game]
    Away <- EPL$AwayTeam[game]
    
    # determine points for home and away team (will remain 0 if team has lost)
    HomePts <- AwayPts <- 0
    if(EPL$FTR[game]=="D"){
      HomePts <- AwayPts <- 1
    } else if(EPL$FTR[game]=="H") {
      HomePts <- 3
    } else {
      AwayPts <- 3
    }
    
    # find row of current home team, add home result to next available column (match day)
    H_ind <- which(rownames(WLD_prog)==Home)
    H_MD_ind <- min(which(is.na(WLD_prog[H_ind,])))
    WLD_prog[H_ind,H_MD_ind] <- HomePts
    # find row of current away team, add away result to next available column (match day)
    A_ind <- which(rownames(WLD_prog)==Away)
    A_MD_ind <- min(which(is.na(WLD_prog[A_ind,])))
    WLD_prog[A_ind,A_MD_ind] <- AwayPts
    
  }

  # add current season data to the the global list
  WLD_prog_list[[season]] <- WLD_prog
  # add 380 to start/end index values for the next season
  start_ind <- start_ind + games_per_season
  end_ind <- end_ind + games_per_season
}



# 
WLD_prog_list2 <- vector("list", length=num_seasons)

# 
for (season in 1:num_seasons) {
  # 
  WLD_prog <- WLD_prog_list[[season]]
  # 
  for(i in 2:ncol(WLD_prog)) {
    WLD_prog[,i] <- WLD_prog[,i] + WLD_prog[,i-1]
  }
  # 
  WLD_prog <- WLD_prog[order(WLD_prog[,38], decreasing = T),]

  # 
  WLD_prog_list2[[season]] <- WLD_prog
}


test <- WLD_prog_list2[[10]]
ptsfinal<-test[,38]
# for(val in ptsfinal) {
#   w <- sum(ptsfinal==val)
#   if(w>1){
#     ind <- min(which(ptsfinal==val))
#     for(i in 1:w){
#       ptsfinal[i+ind-2] <- ((ind-0.5) + i/(1+w))
#     }
#   }
# }

matplot(t(test), type="l", lty=1, lwd=2, col=adjustcolor(1:20,0.5), xlim=c(1,40),
        ylab = "Cumulative Points", xlab = "Game Week", main="Progression of Total Points")
text(40, ptsfinal, rownames(test), cex=0.4)

# use rank method to determine position of each team after each game
# plot progression of league position of each team
posprog <- apply(-test, 2, rank, ties.method="min")
posfinal <- posprog[,38]

# plot league position of each club vs game week
matplot(t(posprog), type="l", lty=rep(c(2,1,3), 8), ylim = c(20,1), lwd=3, col=adjustcolor(1:20,0.9), xlim=c(1,46), xaxt="n", yaxt="n",
        ylab = "League Position", xlab = "Game Week", main="Progression of League Position", bty="n")
# plot x and y axis ticks
axis(1, seq(2,38,2), cex.axis=0.7)
axis(2, 1:20, cex.axis=0.7, las=2)
abline(v=1:38, h=1:20, lty=3, col=adjustcolor("grey", 0.5))
# add legend with teams lined up beside final position
for (i in 1:20) legend(x=39, y=i, yjust = 0.5, rownames(test)[i], lty=rep(c(2,1,3), 8)[i], 
                       col=adjustcolor(i,0.9), lwd=3, bty="n")


for(val in posfinal) {
  w <- sum(posfinal==val)
  if(w>1){
    ind <- min(which(posfinal==val))
    for(i in 1:w){
      posfinal[i+ind-1] <- (ind-0.5) + i/(1+w)
    }
  }
}
text(38, posfinal, rownames(test), cex=0.4)



# Simulating random generation of 3 random probabilities than sum to 1
#
N=100000

r1 <- rep(0,N)
r2 <- rep(0,N)
r3 <- rep(0,N)
for (i in 1:N) {
  rand123 <- rbeta(3,20,20)#runif(3)
  rand123 <- rand123/sum(rand123)
  r1[i] <- rand123[1]
  r2[i] <- rand123[2]
  r3[i] <- rand123[3]
}
par(mfrow=c(3,1))
h1=hist(r1, breaks = 1000, freq = F)
h2=hist(r2, breaks = 1000, freq = F)
h3=hist(r3, breaks = 1000, freq = F)
h1$mids[h1$counts==max(h1$counts)]
h2$mids[h2$counts==max(h2$counts)]
h3$mids[h3$counts==max(h3$counts)]




# use skellam distribution to calculate probability of a Poisson distributed variable (Y1)
# being less than/greater than/equal to a second Poisson distributed variable (Y2)
library(skellam)

# set expected number of home and awau goals (lambdas for Poisson variables)
HomeExGoals <- 2.3
AwayExGoals <- 2.5

# Probability of home win -> P(Y1 > Y2)
P_HomeWin <- pskellam(.1, HomeExGoals , AwayExGoals, lower.tail = F)
# Probability of home win -> P(Y1 < Y2)
P_AwayWin <- pskellam(-.1, HomeExGoals , AwayExGoals)
# Probability of draw -> P(Y1 = Y2)
P_Draw <- dskellam(0, HomeExGoals , AwayExGoals)

P_HomeWin
P_AwayWin 
P_Draw
# should sum to 1
P_HomeWin+P_AwayWin+P_Draw

testt <- cbind(rpois(10000, HomeExGoals), rpois(10000, AwayExGoals))

sum(testt[,1]>testt[,2])/nrow(testt)
sum(testt[,1]<testt[,2])/nrow(testt)
sum(testt[,1]==testt[,2])/nrow(testt)




##########################
# Project Notes / Ideas: #
##########################

# - Try other forms of classification other than random forest
# - Look at plotting progression of league position/points throughout the season using plots
# - Look at introducing the impact of form (e.g. results from last 3/5 games) into the model
# - if form is introduced, figure out how to deal with first 3/5 games of each season before teams have
#   played the required number of fixtures to determine form (i.e. when using data of old games to determine 
#   probabilities using random forest classifiers or similar). Could leave these values out (not ideal) or 
#   estimate them using regression techniques or similar (preferred).
# - Could look at introducing number of goals etc.
# - Potentially look at implementing part 2 of the suggested project lists (e.g. betting odds)
# - For betting, look at adjusting of odds based on volume of bets made (e.g. adjust odds if a large proportion 
#   of bets on any given game are on a particular result to cover the house, as is done in reality)
# - Could set proportions of bets for each game randomly (e.g. get random probabilities of betting on wins, draws and losses)
# - Could review distribution of bets after a certain number of bets are placed (e.g. review after 500, 1000, 1500.... bets are placed), 
#   if bets are biased towards a particular outcome by a particular amount then betting odds could be readjusted,
#   and the proportion of bets probabilities could also potentially be readjusted (people less likely to bet on
#   an outcome if the odds decrease).

N=1000000
r1 <- rep(0,N)
r2 <- rep(0,N)
r3 <- rep(0,N)
for (i in 1:N) {
  a <- runif(1)
  b <- runif(1)
  r1[i] <- min(a,b)
  r2[i] <- abs(a-b)
  r3[i] <- 1-max(a,b)
}
par(mfrow=c(3,1))
hist(r1, breaks = 100)
hist(r2, breaks = 100)
hist(r3, breaks = 100)







