SELECT *
FROM PortfolioPrj..covid_deaths
ORDER BY 3,4

--SELECT *
--FROM PortfolioPrj..covid_vaccination
--ORDER BY 3,4

SELECT location, date, CAST(total_cases as int) total_cases, CAST(new_cases as int) new_cases, CAST(total_deaths as int) total_deaths, population
FROM PortfolioPrj..covid_deaths
ORDER BY 1,2

-- Looking as Total Cases vs Total Deaths
-- Shows the likelihood of dying if you are infected with COVID in Australia

SELECT location, date, CAST(total_cases as int) total_cases, CAST(total_deaths as int) total_deaths, (CAST(total_deaths as float)/ CAST(total_cases as float)) * 100 as Death_Percentage
FROM PortfolioPrj..covid_deaths
--WHERE location = 'Australia'
ORDER BY 1,2

-- Looking as Total Cases vs Population
-- Shows percentage of population infected with COVID

SELECT location, date, CAST(total_cases as int) total_cases, population, (total_cases/population)*100 as Infection_Rate
FROM PortfolioPrj..covid_deaths
--WHERE location = 'Australia'
ORDER BY 1,2

-- Looking at countries with highest infection rate compared relative to its population

SELECT location, population, MAX(CAST(total_cases as int)) as highest_infection, (MAX(CAST(total_cases as int))/population)*100 as percentage_population_infected
FROM PortfolioPrj..covid_deaths
--WHERE location = 'Australia'
GROUP BY location, population
ORDER BY percentage_population_infected desc

-- Looking at countries with highest death count

SELECT location, MAX(cast(total_deaths as int)) as total_death_count
FROM PortfolioPrj..covid_deaths
WHERE continent IS NOT NULL
GROUP BY location
ORDER BY total_death_count desc

-- Showing continents with highest death rate 

SELECT continent, MAX(cast(total_deaths as int)) as total_death_count
FROM PortfolioPrj..covid_deaths
WHERE continent IS NOT NULL
GROUP BY continent
ORDER BY total_death_count DESC


-- Global numbers

SELECT date, SUM(CAST(total_cases as int)) total_cases, SUM(CAST(total_deaths as int)) total_deaths, (SUM(CAST(total_deaths as float))/SUM(CAST(total_cases as float))) * 100 as Death_Percentage
FROM PortfolioPrj..covid_deaths
--WHERE location = 'Australia'
WHERE continent IS NOT NULL
GROUP BY date
ORDER BY 1,2 


--Joining the vaccination table

SELECT TOP 50000
dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations, 
SUM(CAST(vac.new_vaccinations AS int)) OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) as rolling_vac_total
FROM PortfolioPrj..covid_deaths dea
JOIN PortfolioPrj..covid_vaccination vac
	ON dea.location = vac.location
	and dea.date = vac.date
WHERE dea.continent is NOT NULL
--and dea.location = 'Australia'
ORDER BY 2,3


-- USING CTE

WITH popvsvac (continent, location, date, population, new_vaccinations, rolling_vac_total)
as

(SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations, 
SUM(CAST(vac.new_vaccinations AS bigint)) OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) as rolling_vac_total
FROM PortfolioPrj..covid_deaths dea
JOIN PortfolioPrj..covid_vaccination vac
	ON dea.location = vac.location
	and dea.date = vac.date
WHERE dea.continent is NOT NULL
--ORDER BY dea.location, dea.date
)

SELECT *, (rolling_vac_total/population)*100 as perc_pop_vac
FROM popvsvac


--USING TEMP TABLES

DROP TABLE if exists #Perc_population_vac
CREATE TABLE #Perc_population_vac

(
Continent nvarchar(225),
Location nvarchar(255),
Date datetime,
Population numeric,
new_vaccination numeric,
rolling_vac_total numeric
)

INSERT INTO #Perc_population_vac
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations, 
SUM(CAST(vac.new_vaccinations AS bigint)) OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) as rolling_vac_total
FROM PortfolioPrj..covid_deaths dea
JOIN PortfolioPrj..covid_vaccination vac
	ON dea.location = vac.location
	and dea.date = vac.date
WHERE dea.continent is NOT NULL

SELECT *, (rolling_vac_total/population)*100 as perc_pop_vac
FROM #Perc_population_vac


-- creating view to store data for viz later

CREATE VIEW global_death_rate_continent2 AS
SELECT continent, MAX(cast(total_deaths as int)) as total_death_count
FROM PortfolioPrj..covid_deaths
WHERE continent IS NOT NULL
GROUP BY continent
--ORDER BY total_death_count DESC