# OGSUQ.jl

## Contents

```@contents
Pages = ["index.md"]
Depth = 5
```

## The principle idea for the creation of a stochastic OGS6 project

The principle idea is to always start with a fully configured and running deterministic OGS6 project. There are three basic functions which create three individual xml-files which are used to define the stochastic OGS project. These files are human-readable and can be manually configured and duplicated for the use in other, or slightly altered, stochastic projects.

The first function 
```julia
generatePossibleStochasticParameters(
	projectfile::String, 
	file::String="./PossibleStochasticParameters.xml", 
	keywords::Vector{String}=ogs_numeric_keyvals
	)
```
scans an existing `projectfile` for all parameters which can be used in a stochastic project. What is considered to be a possible stochastic parameter is defined by the [`keywords`](../../src/OGSUQ/utils.jl#L2). By this, an xml-file `file` is generated where all possible stochastic parameters are listed. 

The second function

```julia
generateStochasticOGSModell(
	projectfile::String,
	simcall::String,
	additionalprojecfilespath::String,
	postprocfile::Vector{String},
	stochpathes::Vector{String},
	outputpath="./Res",
	stochmethod=AdaptiveHierarchicalSparseGrid,
	n_local_workers=50,
	keywords=ogs_numeric_keyvals,
	sogsfile="StochasticOGSModelParams.xml"
	)
```
creates an xml-file which defines the so-called `StochasticOGSModelParams`. It is defined by 
- the location to the existing `projectfile`, 
- the `simcall` (e.g. `"path/to/ogs/bin/ogs"`), 
- a `additionalprojecfilespath` where meshes and other files can be located which are copied in each individual folder for a OGS6-snapshot, 
- the path to one or more `postprocfile`s, 
- the stochpathes, generated with `generatePossibleStochasticParameters`, manipulated by the user, and loaded by the `loadStochasticParameters`-function,
- an `outputpath`, where all snapshots will be stored,
- a `stochmethod` (Sparse grid or Monte-Carlo, where Monte-Carlo is not yet implemented),
- the number of local workers `n_local_workers`, and, 
- the filename `sogsfile` under which the model is stored as an xml-file. 

This function also creates a file `user_function.jl` which is loaded by all workers and serves as an interface between OGS6 and Julia. Here it is defined how the individual snaptshots are generated and how the postprocessing results are handled.

The third and last function

```julia
generateSampleMethodModel(
	sogsfile::String, 
	anafile="SampleMethodParams.xml"
	)
# or
generateSampleMethodModel(
	sogs::StochasticOGSModelParams, 
	anafile="SampleMethodParams.xml"
	)
```
creates an xml-file `anafile` with all necessary parameters for the chosen sample method in the `StochasticOGSModelParams`.

## Usage

In this chapter, [Example 1](https://github.com/baxmittens/OGSUQ.jl/tree/main/test/ex1) is used to illustrate the workflow. The underlying deterministic OGS6 project is the [point heat source example](https://www.opengeosys.org/docs/benchmarks/th2m/saturatedpointheatsource/) ([Thermo-Richards-Mechanics project files](https://gitlab.opengeosys.org/ogs/ogs/-/tree/master/Tests/Data/ThermoRichardsMechanics/PointHeatSource)).


### Defining the stochastic dimensions

The following [lines of code](../../test/ex1/generate_stoch_params_file.jl) 
```julia
using OGSUQ
projectfile="./project/point_heat_source_2D.prj"
pathes = generatePossibleStochasticParameters(projectfile)
```
return an array of strings with [`OGS6-XML-pathes`](https://github.com/baxmittens/Ogs6InputFileHandler.jl/blob/63944f2bcc54238af568f5f892677925ba171d5a/src/Ogs6InputFileHandler/utils.jl#L51) and generates an XML-file [`PossibleStochasticParameters.xml`](../../test/ex1/PossibleStochasticParameters.xml) in the working directory

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Array
	 julia:type="String,1"
>
	./media/medium/@id/0/phases/phase/?AqueousLiquid/properties/property/?specific_heat_capacity/value
	./media/medium/@id/0/phases/phase/?AqueousLiquid/properties/property/?thermal_conductivity/value
			.
			.
			.
	./parameters/parameter/?displacement0/values
	./parameters/parameter/?pressure_ic/values
</Array>
```
where all parameters possible to select as stochastic parameter are mapped. Since, in this example, an adaptive sparse grid collocation sampling shall be adopted, only two parameters, the porosity and the thermal conductivity of the aqueous liquid,
```
./media/medium/@id/0/properties/property/?porosity/value
./media/medium/@id/0/phases/phase/?AqueousLiquid/properties/property/?thermal_conductivity/value
```
are selected. Thus, all other parameters are deleted from the file. The resulting xml-file is stored as [`altered_PossibleStochasticParameters.xml`](./test/ex1/altered_PossibleStochasticParameters.xml) in the working directory.

### Defining the stochastic model

The following [code snippet](./test/ex1/generate_stoch_model.jl) 
```julia
using OGSUQ
projectfile="./project/point_heat_source_2D.prj"
simcall="/path/to/ogs/bin/ogs"
additionalprojecfilespath="./mesh"
outputpath="./Res"
postprocfiles=["PointHeatSource_ts_10_t_50000.000000.vtu"]
outputpath="./Res"
stochmethod=AdaptiveHierarchicalSparseGrid
n_local_workers=50

stochparampathes = loadStochasticParameters("altered_PossibleStochasticParameters.xml")
	
stochasticmodelparams = generateStochasticOGSModell(
	projectfile,
	simcall,
	additionalprojecfilespath,
	postprocfiles,
	stochparampathes,
	outputpath,
	stochmethod,
	n_local_workers) # generate the StochasticOGSModelParams

samplemethodparams = generateSampleMethodModel(stochasticmodelparams) # generate the SampleMethodParams
```

generates two XML-files, [`StochasticOGSModelParams.xml`](./test/ex1/StochasticOGSModelParams.xml) and [`SampleMethodParams.xml`](./test/ex1/SampleMethodParams.xml), defining the stochastic model.

Again, these files are altered and stored under [`altered_StochasticOGSModelParams.xml`](./test/ex1/altered_StochasticOGSModelParams.xml) and [`altered_SampleMethodParams.xml`](./test/ex1/altered_SampleMethodParams.xml).

In the former, the two stochastic parameters are altered. The probability distribution of the porosity is changed from `Uniform` to `Normal` with mean `μ=0.375` and standard deviation `σ=0.1`.
```xml
<StochasticOGS6Parameter
	 path="./media/medium/@id/0/properties/property/?porosity/value"
	 valspec="1"
	 lower_bound="0.15"
	 upper_bound="0.60"
>
	<Normal
		 julia:type="Float64"
		 julia:fieldname="dist"
		 μ="0.375"
		 σ="0.1"
	/>
</StochasticOGS6Parameter>
```
Note that for efficiency, the normal distribution is changed to a [truncated normal distribution](https://en.wikipedia.org/wiki/Truncated_normal_distribution) by the parameters `lower_bound=0.15` and `upper_bound=0.60`. This results in an integration error of approximately 2.5% for this example. See the picture below for a visualization of the normal distribution $\mathcal{N}$ and the truncated normal distribution $\bar{\mathcal{N}}$.

```@raw html
<p align="center">
	<img src="https://user-images.githubusercontent.com/100423479/223678210-58ebf8c4-731a-4a5e-9037-693f80d431b4.png" width="350" height="350" />
</p>
```

The second parameter, the thermal conductivity, is set up as a truncated normal distribution with mean `μ=0.6`, standard deviation `σ=0.05`, `lower_bound=0.5`, and, `upper_bound=0.7`. The multivariate truncated normal distribution resulting from the convolution of both one-dimensional distributions is pictured below. Note, that the distribution has been transformed to the domain $[-1,1]^2$ of the [sparse grid](https://github.com/baxmittens/DistributedSparseGrids.jl).

```@raw html
<p align="center">
	<img src="https://user-images.githubusercontent.com/100423479/223682880-2be481cc-986a-4f00-a47a-042d0b0684e5.png" width="400" height="250" />
</p>
```

The second file [`altered_SampleMethodParams.xml`](./test/ex1/altered_SampleMethodParams.xml) defines the sample method parameters such as
- the number of dimensions `N=2`,
- the return type `RT="VTUFile"` (see [VTUFileHandler.jl](https://github.com/baxmittens/VTUFileHandler.jl))
- the number of initial hierachical level of the sparse grid `init_lvl=4`,
- the number of maximal hierarchical level of the sparse grid `maxlvl=20`, and,
- the minimum hierarchical surplus for the adaptive refinement `tol=100000.0`.

Note, that the refinement tolerance was chosen as a large value since at the moment the reference value is the `LinearAlgebra.norm(::VTUFile)` of the entire result file.

### Sampling the model

The following [lines of code](./test/ex1/start.jl)

```julia
using OGSUQ
ogsuqparams = OGSUQParams("altered_StochasticOGSModelParams.xml", "altered_SampleMethodParams.xml")
ogsuqasg = OGSUQ.init(ogsuqparams)
OGSUQ.start!(ogsuqasg)
expval,asg_expval = OGSUQ.𝔼(ogsuqasg)
```

load the parameters `ogsuqparams`, initializes the model `ogsuqasg`, and, starts the sampling procedure. Finally the expected value is integrated.

* Initializing the model `OGSUQ.init(ogsuqparams)` consists of two steps
	
    1. Adding all local workers (in this case 50 local workers)
    2. Initializing the adaptive sparse grid.

* Starting the sampling procedure `OGSUQ.start!(ogsuqasg)` first creates 4 initial hierarchical levels levels and, subsequently, starts the adaptive refinement. This first stage results in an so-called *surrogate model* of the physical domain defined by the boundaries of the stochastic parameters

```@raw html
<table border="0"><tr>
<td> 
	<figure>
		<img src="https://user-images.githubusercontent.com/100423479/223154558-4b94d7a2-e93b-45ef-9783-11437ae23b35.png" width="350" height="300" /><br>
		<figcaption><em>resulting sparse grid</em></figcaption>
	</figure>
</td>
<td> 
	<figure>
		<img src="./assets/response_surface_expval.png" width="350" height="300" /><br>
		<figcaption><em>response surface</em></figcaption>
	</figure>
</td>
</tr></table>
```



### Computation of the expected value

```julia
import VTUFileHandler
expval,asg_expval = OGSUQ.𝔼(ogsuqasg);
VTUFileHandler.rename!(expval,"expval_heatpointsource.vtu")
write(expval)
```

```@raw html
<table border="0"><tr>
<td> 
	<figure>
		<img src="./assets/asg_expval.png" width="350" height="300" /><br>
		<figcaption><em>resulting sparse grid</em></figcaption>
	</figure>
</td>
<td> 
	<figure>
		<img src="./assets/response_surface.png" width="350" height="300" /><br>
		<figcaption><em>response surface</em></figcaption>
	</figure>
</td>
</tr></table>
```

### Computation of the variance

```julia
varval,asg_varval = OGSUQ.var(ogsuqasg,expval);
```


## Contributions, report bugs and support

Contributions to or questions about this project are welcome. Feel free to create a issue or a pull request on [GitHub](https://github.com/baxmittens/VTUFileHandler.jl).