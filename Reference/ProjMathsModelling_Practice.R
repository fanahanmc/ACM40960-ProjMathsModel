setwd("/Users/fanahanmcsweeney/Projects/STAT40620-R-Project")

EPL_18_19 <- read.csv("Data/season-1819_csv.csv", header=TRUE)
EPL_18_19 <- EPL_18_19[,c("HomeTeam", "AwayTeam", "FTR")]
teams <- unique(EPL_18_19$HomeTeam)

teams_WLD <- matrix(NA, length(teams), 5)
colnames(teams_WLD) <- c("W", "D", "L", "Points", "Points%")
rownames(teams_WLD) <- teams

# Calculate number of wins/losses/draws/points and % of total possible points achieved by each team
for (team in teams) {
  Ws <- sum((EPL_18_19[,"HomeTeam"]==team & EPL_18_19[,"FTR"]=="H") | (EPL_18_19[,"AwayTeam"]==team & EPL_18_19[,"FTR"]=="A"))
  Ds <- sum((EPL_18_19[,"HomeTeam"]==team | EPL_18_19[,"AwayTeam"]==team) & EPL_18_19[,"FTR"]=="D")
  Ls <- sum((EPL_18_19[,"HomeTeam"]==team & EPL_18_19[,"FTR"]=="A") | (EPL_18_19[,"AwayTeam"]==team & EPL_18_19[,"FTR"]=="H"))
  Ps <- 3*Ws + 1*Ds
  PsPC <- Ps/114

  # get row index of currently selected team, add current values to that row
  ind <- which(rownames(teams_WLD)==team)
  teams_WLD[ind,] <- c(Ws, Ds, Ls, Ps, PsPC)
}

# Create copy of data frame
EPL_18_19_copy <- EPL_18_19
# create empty columns to store % total possible points achieved for the home and away teams for each fixture
EPL_18_19_copy$HomePPC <- 0
EPL_18_19_copy$AwayPPC <- 0

# add % of total points for current row home and away teams to the corresponding columns
for (i in 1:nrow(EPL_18_19_copy)) {
  H_ind <- which(rownames(teams_WLD)==EPL_18_19_copy$HomeTeam[i])
  A_ind <- which(rownames(teams_WLD)==EPL_18_19_copy$AwayTeam[i])
  
  EPL_18_19_copy$HomePPC[i] <- teams_WLD[H_ind,"Points%"]
  EPL_18_19_copy$AwayPPC[i] <- teams_WLD[A_ind,"Points%"]
}

teams_WLD
head(EPL_18_19_copy)

df <- data.frame(EPL_18_19_copy)
df$FTR <- as.factor(df$FTR)

# boxplot of difference in % total points between home and away teams, separated by result
boxplot((df$HomePPC-df$AwayPPC)~df$FTR)

# classification of WDA
library(randomForest)

# function to calculate classification accuracy
class_acc <- function(y, yhat) {
  tab <- table(y, yhat)
  return(sum(diag(tab))/sum(tab) )
}


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

pred_prob

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



# table0 <- rep(0,3)
# Nreps <- 100000
# for(rep in 1:Nreps) {
#   
#   rrr <- rep(0, nrow(df))
#   # for each fixture, sample the result using predicted probabilities
#   for(i in 1:nrow(pred_prob_all)) {
#     rrr[i] <- sample(c("A", "D", "H"), 1, prob = pred_prob_all[i,])
#   }
#   table0 <- table0 + table(rrr)
#   
#   if(rep%%100==0) {print(rep)}
#   
# }
# table0/Nreps









###########################################################
# Load 10 seasons worth of results and repeat steps above #
###########################################################


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
  Reduce(function(x,y) {merge(x, y, all = TRUE)}, datalist)
}

                
# call mergeFiles function to create data frame of all csv files
EPL_raw <- mergeFiles(folderpath)
# drop unwanted columns
EPL <- EPL_raw[,c("HomeTeam", "AwayTeam", "FTR")]

# print column names
names(EPL)
dim(EPL)



teams <- unique(EPL$HomeTeam)

teams_WLD <- matrix(NA, length(teams), 5)
colnames(teams_WLD) <- c("W", "D", "L", "Points", "Points%")
rownames(teams_WLD) <- teams

# Calculate number of wins/losses/draws/points and % of total possible points achieved by each team
for (team in teams) {
  Ws <- sum((EPL[,"HomeTeam"]==team & EPL[,"FTR"]=="H") | (EPL[,"AwayTeam"]==team & EPL[,"FTR"]=="A"))
  Ds <- sum((EPL[,"HomeTeam"]==team | EPL[,"AwayTeam"]==team) & EPL[,"FTR"]=="D")
  Ls <- sum((EPL[,"HomeTeam"]==team & EPL[,"FTR"]=="A") | (EPL[,"AwayTeam"]==team & EPL[,"FTR"]=="H"))
  Ps <- 3*Ws + 1*Ds
  PsPC <- Ps/(sum(Ws+Ds+Ls)*3)
  
  # get row index of currently selected team, add current values to that row
  ind <- which(rownames(teams_WLD)==team)
  teams_WLD[ind,] <- c(Ws, Ds, Ls, Ps, PsPC)
}









