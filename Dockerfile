# Get the base imgae for .NET-Core-SDK from Microsoft
FROM mcr.microsoft.com/dotnet/sdk:7.0 AS build-env
ARG includetests=true
WORKDIR /app
ARG version=1.0.0
SHELL ["/bin/bash", "-c"]

# install apt packages
RUN apt-get update && apt-get install -yq build-essential make \
&& apt-get clean \
&& rm -rf /var/lib/apt/lists/*

# Copy the project files and restore all dependencies
COPY StatusCodes.sln ./
COPY ./StatusCodes.Api/ ./StatusCodes.Api
COPY ./StatusCodes.Api.Unit.Tests/ ./StatusCodes.Api.Unit.Tests
COPY ./StatusCodes.Integration.Tests/ ./StatusCodes.Integration.Tests

COPY . ./
RUN dotnet restore StatusCodes.sln

# Run tests, use the label to identity this layer later
LABEL test=true

# install the report generator tool
RUN dotnet new tool-manifest
RUN dotnet tool install dotnet-reportgenerator-globaltool --version 5.1.26 --tool-path ./tools
 
# run the test and collect code coverage (requires coverlet.msbuild to be added to test project)
# for exclude, use %2c for ,
RUN dotnet test --filter FullyQualifiedName~Unit.Tests --collect:"XPlat Code Coverage" --results-directory /unittestresults --logger "trx;LogFileName=unittest_results.xml" /p:CollectCoverage=true /p:CoverletOutputFormat=json%2cCobertura /p:CoverletOutput=/unittestresults/coverage/ /p:Exclude="[xunit.*]*%2c[StackExchange.*]*" ; exit 0

# Comment out Integration tests for now, requires other real services or wiremock services deployed to this agent 
# RUN dotnet test --filter FullyQualifiedName~Integration.Tests --collect:"XPlat Code Coverage" --results-directory /integrationtestresults --logger "trx;LogFileName=integrationtest_results.xml" /p:CollectCoverage=true /p:CoverletOutputFormat=cobertura /p:CoverletOutput=./integrationtestresults/coverage/ /p:Exclude="[xunit.*]*%2c[StackExchange.*]*" ; exit 0

# Check for zero errors
RUN testxml=/unittestresults/unittest_results.xml; \
    test_counters=$(expr match "$test_counters" '\(.*/>\)'); \
    failed_tests=$(echo "$test_counters" | grep -o 'failed="[0-9]\+"' | awk -F'"' '{print $2}'); \
    exit $failed_tests

# build and publish
RUN dotnet publish StatusCodes.Api/StatusCodes.Api.csproj -c Release -o out /p:Version=${version}

# Build runtime image
FROM mcr.microsoft.com/dotnet/aspnet:7.0 AS base
WORKDIR /app
EXPOSE 80
COPY AppBinaries/*.*  .
ENTRYPOINT ["dotnet", "StatusCodes.Api.dll"]
