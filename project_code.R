## Home Value Patrol - A study to understand the effect of crime on home values in Seattle

# Set Working Directory
setwd("C:/Users/UW_STUDENT_Virtual/Desktop/572/572 - Group Project")

# Required Packages for Project
# 1. gpclib: General Polygon Clipping Library for R
# 2. rgeos: Interface to Geometry Engine - Open Source (GEOS)
# 3. maptools: Tools for Reading and Handling Spatial Objects
# 4. rgdal: Bindings for the Geospatial Data Abstraction Library
# 5. ggplot2: graphing library for R
# 6. spatialEco: Spatial Analysis and Modelling
# 7. tidyr: Data cleaning operations
# 8. dplyr: Data Manipulation

install.packages("gpclib")
install.packages("rgeos")
install.packages("maptools")
install.packages("rgdal")
install.packages("ggplot2")
install.packages("spatialEco")
install.packages("tidyr")
install.packages("dplyr")
install.packages("ggmap")

# Loading the packages

library("tidyr")
library("dplyr")
library("gpclib")
library("maptools")
library("rgdal")
library("ggplot2")
library("rgeos")
require("maptools")
library("spatialEco")
library("ggmap")
library("plyr")

# Importing Datasets

# Seattle_Police_Department_911_Incident_Response.csv -- Source: data.seattle.gov
# URL: https://data.seattle.gov/Public-Safety/Seattle-Police-Department-911-Incident-Response/3k2p-39jp

raw.data_911 <- read.csv("Seattle_Police_Department_911_Incident_Response.csv")
View(raw.data_911)

# Zhvi_YearlyTrends.csv -- Source: Zillow Data Research
# URL: http://files.zillowstatic.com/research/public/Neighborhood/Neighborhood_Zhvi_AllHomes.csv

raw.data_zillow <- read.csv("Zhvi_YearlyTrends.csv")
View(raw.data_zillow)

# Data Cleaning: Transforming raw data and eliminating redundancies

reqd_cols <- c("Event.Clearance.SubGroup","Event.Clearance.Group","Event.Clearance.Date","Hundred.Block.Location",
               "District.Sector","Zone.Beat","Longitude","Latitude", "Incident.Location")

reqd_events <- c("ARREST", "ASSAULTS","BURGLARY","DISTURBANCES","ROBBERY","TRESSPASS")

clean.data_911 <- subset(raw.data_911, 
                         raw.data_911$Event.Clearance.Group !="NULL" & 
                         raw.data_911$Event.Clearance.Group %in% reqd_events & 
                         raw.data_911$Incident.Location != "NULL"& 
                         raw.data_911$Event.Clearance.Date != "NULL" &
                         raw.data_911$Event.Clearance.Date != "")[reqd_cols]

clean.data_911["Year"]<-substr(as.character(clean.data_911$Event.Clearance.Date),7,10)
clean.data_911["Month"]<-substr(as.character(clean.data_911$Event.Clearance.Date),1,2)
clean.data_911["POSIXct_date"]<-as.POSIXct(substr(as.character(clean.data_911$Event.Clearance.Date),1,10),format="%m/%d/%Y")
clean.data_911 <- subset(clean.data_911, clean.data_911$Year >= 2010)

# Exploratory Analysis on 911 data

# Exploring the number of instances of individual crimes since 2010
clean.data_911$Event.Clearance.Group <- factor(clean.data_911$Event.Clearance.Group)
crime.frequency <- as.data.frame(table(clean.data_911$Event.Clearance.Group))

View(crime.frequency)
colnames(crime.frequency) = c("crime","count")

ggplot(data = crime.frequency, aes(x = crime, y=count,fill=crime)) +
    geom_bar(stat = "identity", color = "white", width = 0.75) +
    ggtitle("Crime Frequency since 2010") 
   

# Exploring the crime rates by year

clean.data_911$Year <- factor(clean.data_911$Year)
crime.frequency.year <- as.data.frame(table(clean.data_911$Year))
View(crime.frequency.year)
colnames(crime.frequency.year) = c("year","count")

ggplot(data = crime.frequency.year, aes(x = year, y=count, fill=count)) +
  geom_bar(stat = "identity", color = "white", width = 0.85) +
  ggtitle("Crime statistics by year")

# Exploring Seattle Map and plotting our crime data

seattle.map <- qmap('Seattle',zoom=11, maptype = "hybrid")
seattle.map + geom_point(data = clean.data_911, aes(x = clean.data_911$Longitude, y = clean.data_911$Latitude), color = "coral", alpha = 0.02, na.rm = TRUE, size = 4) +
  ggtitle("Crime in Seattle") + 
  xlab("Longitude") +
  ylab("Latitude") 

# Cleaning 911 data further by mapping longitude + latitude to neighborhoods

# Using shape files to draw neighborhoods
map <- readOGR("Neighborhoods.shp", layer="Neighborhoods")

clean.data_911 <- clean.data_911[complete.cases(clean.data_911),]
coordinates(clean.data_911)<-~Longitude+Latitude # Adding coordinates column

# projecting the coordinates to a format that can be read by the shapefile  
# creates a special dataframe called : SpatialPointsDataFrame
proj4string(clean.data_911)<-CRS("+proj=longlat +datum=NAD83")
clean.data_911<-spTransform(clean.data_911, CRS(proj4string(map)))

# Joining the shape file and data_911. 
# The coordinate of each 911 call is mapped to the neighborhood from the shapefile
pts <- point.in.poly(clean.data_911,map)
neighborhood.911_data <- data.frame(pts)
neighborhood.911_data<-neighborhood.911_data[c("Year","Month","Event.Clearance.Group","Event.Clearance.SubGroup","S_HOOD","L_HOOD")] 

# Some more manual cleaning in neighborhoods to refine zones

unique(subset(neighborhood.911_data, neighborhood.911_data$L_HOOD=="CENTRAL AREA")$S_HOOD)
neighborhood.911_data$S_HOOD <-  as.character(neighborhood.911_data$S_HOOD)
neighborhood.911_data$S_HOOD[which(neighborhood.911_data$S_HOOD %in% "Adams")]<-"Ballard"
neighborhood.911_data$S_HOOD[which(neighborhood.911_data$S_HOOD %in% "Mid-Beacon Hill")]<-"Beacon Hill"
neighborhood.911_data$S_HOOD[which(neighborhood.911_data$S_HOOD %in% c("Broadway","Stevens"))] <- "Capitol Hill"
neighborhood.911_data$S_HOOD[which(neighborhood.911_data$S_HOOD %in% c("Central Business District","International District","Pike-Market","Pioneer Square","Yesler Terrace"))]<-"Downtown"
neighborhood.911_data$S_HOOD[which(neighborhood.911_data$S_HOOD %in% c("Briancliff","Lawton Park","Southeast Magnolia"))] <- "Magnolia"
neighborhood.911_data$S_HOOD[which(neighborhood.911_data$S_HOOD %in% c("Atlantic","Harrison/Denny-Blaine","Mann"))] <- "Central"

# Cleaning up Zillow Dataset
# Eliminating all cities except City == Seattle

raw.data_zillow <- subset(raw.data_zillow,raw.data_zillow$City=="Seattle")

raw.data_zillow$Metro <- NULL
raw.data_zillow$City <- NULL
raw.data_zillow$State <- NULL
raw.data_zillow$CountyName <- NULL

rownames(raw.data_zillow) <- raw.data_zillow[,"RegionName"]
raw.data_zillow["RegionName"] <- NULL
clean.data_zillow <- data.frame(t(raw.data_zillow))
clean.data_zillow["ym"] <- rownames(clean.data_zillow)
clean.data_zillow["Year"] <- substr(clean.data_zillow$ym,2,5)
clean.data_zillow["Month"] <- substr(clean.data_zillow$ym,7,8)
clean.data_zillow["ym"] <- NULL
rownames(clean.data_zillow) <- NULL
clean.data_zillow <- clean.data_zillow %>% gather("Neighborhood",zvhi_score, Capitol.Hill:Jackson.Place)
clean.data_zillow$Neighborhood <- gsub("[.]"," ",clean.data_zillow$Neighborhood)
colnames(clean.data_zillow) <- c("year","month","neighborhood","home.value")

# Manual neighborhood cleanup for Zillow - 911 intersection

clean.data_zillow$neighborhood[which(clean.data_zillow$neighborhood %in% "Mt  Baker")] <- "Mount Baker"