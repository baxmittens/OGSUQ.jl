
ogs_numeric_keyvals = ["value","reference_condition","slope", "reference_value","specific_body_force","values"]
function generatePossibleStochasticParameters(projectfile::String, file::String="./PossibleStochasticParameters.xml", keywords::Vector{String}=ogs_numeric_keyvals)
	modeldef = read(Ogs6ModelDef,projectfile)
	stochparams = Vector{StochasticOGS6Parameter}()
	pathes = Vector{String}()
	for keyword in keywords
		getAllPathesbyTag!(pathes,modeldef.xmlroot,keyword)
	end
	#writeXML(Julia2XML(pathes), file)
	write(file, Julia2XML(pathes))
	return pathes
end

function loadStochasticParameters(file::String="./PossibleStochasticParameters.xml")
	pathes = XML2Julia(read(XMLFile, file))
	return pathes
end

function createUserFiles(outfile::String, sogsfile::String, templatefile::String) where {N,CT,RT}
	f = open(templatefile)
	str = read(f,String)
	close(f)
	str = replace(str, "_ogsp_placeholder_"=>"$(sogsfile)")
	f = open(outfile, "w")
	write(f,str)
	close(f)
	println("Function template file written to $outfile")
end

function generateStochasticOGSModell(
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

	modeldef = read(Ogs6ModelDef,projectfile)
	stochparams = Vector{StochasticOGS6Parameter}()
	#remote_workers = Tuple{String,Int}[]
	sort!(stochpathes)
	for path in stochpathes
		valspec = 1
		dist = Uniform(0,1)
		lb = -1
		ub = 1
		user_function = x->x
		push!(stochparams, StochasticOGS6Parameter(path,valspec,dist,lb,ub))
	end

	templatefile = joinpath(@__DIR__,"user_function_template.jl")
	outfile = "./user_functions.jl"
	createUserFiles(outfile,sogsfile,templatefile)

	ogs6pp = OGS6ProjectParams(projectfile,simcall,additionalprojecfilespath,outputpath,postprocfile)
	#sogs = OGSUQParams(ogs6pp,stochparams,stochmethod,n_local_workers,remote_workers,sogsfile)
	sogs = StochasticOGSModelParams(ogs6pp,stochparams,stochmethod,n_local_workers,outfile,sogsfile)
	writeXML(Julia2XML(sogs), sogsfile)
	if !isdir(ogs6pp.outputpath)
		run(`mkdir $(ogs6pp.outputpath)`)
		println("Created Resultfolder $(ogs6pp.outputpath)")
	end
	return sogs
end

function generateSampleMethodModel(::Type{AdaptiveHierarchicalSparseGrid}, sogs::StochasticOGSModelParams, anafile="SampleMethodParams.xml")
	N = length(sogs.stochparams)
	CT = Float64
	RT = VTUFile
	pointprobs = Int[1 for i = 1:N]
	init_lvl = N+1
	maxlvl = 20
	tol = 1e-2
	smparams = SparseGridParams(N,CT,RT,pointprobs,init_lvl,maxlvl,tol,anafile)
	writeXML(Julia2XML(smparams), anafile)
	return smparams
end

function generateSampleMethodModel(sogs::StochasticOGSModelParams, anafile="SampleMethodParams.xml")
	return generateSampleMethodModel(sogs.samplemethod, sogs, anafile)
end

function lin_func(x,xmin,ymin,xmax,ymax)
	a = (ymax-ymin)/(xmax-xmin)
	b = ymax-a*xmax
	return a*x+b
end
function CPtoStoch(x,stoparam)
	return lin_func(x, -1.0, stoparam.lower_bound, 1.0, stoparam.upper_bound)
end

#function CTtoStoParam(x,stoparam)
#	return lin_func(x, -1.0, stoparam.lower_bound, 1.0, stoparam.upper_bound)
#end

function setStochasticParameter!(modeldef::Ogs6ModelDef, stoparam::StochasticOGS6Parameter, x, user_func::Function,cptostoch::Function=CPtoStoch)
	vals = getElementbyPath(modeldef, stoparam.path)
	splitstr = split(vals.content[1])
	splitstr[stoparam.valspec] = string(user_func(cptostoch(x,stoparam)))
	vals.content[1] = join(splitstr, " ")
	return nothing
end

function setStochasticParameters!(modeldef::Ogs6ModelDef, stoparams::Vector{StochasticOGS6Parameter}, x, user_funcs::Vector{Function},cptostoch::Function=CPtoStoch)
	foreach((_x,_y,_z)->setStochasticParameter!(modeldef, _y, _x, _z, cptostoch), x, stoparams, user_funcs)
	return nothing
end

function pdf(stoparam::StochasticOGS6Parameter, x::Float64)
	val = lin_func(x, -1.0, stoparam.lower_bound, 1.0, stoparam.upper_bound)
	return pdf(stoparam.dist, val)/(cdf(stoparam.dist, stoparam.upper_bound)-cdf(stoparam.dist, stoparam.lower_bound))*(0.5*abs(stoparam.upper_bound-stoparam.lower_bound))
	#return pdf(stoparam.dist, val)/(cdf(stoparam.dist, stoparam.upper_bound)-cdf(stoparam.dist, stoparam.lower_bound))#*(0.5*abs(stoparam.upper_bound-stoparam.lower_bound))
end

function pdf(stoparams::Vector{StochasticOGS6Parameter}, x)
	return foldl(*,map((x,y)->pdf(x,y),stoparams,x))
end

#function ASG(ana::AHSGAnalysis{N, CT, RT}, _fun, tol=1e-4) where {N,CT,RT}
#	asg = init(AHSG{N,HierarchicalCollocationPoint{N,CollocationPoint{N,CT},RT}},ana.pointprobs)
#	cpts = Set{HierarchicalCollocationPoint{N,CollocationPoint{N,CT},RT}}(collect(asg))
#	for i = 1:5
#		union!(cpts,generate_next_level!(asg))
#	end
#	@time init_weights_inplace_ops!(asg, collect(cpts), _fun)
#	for i = 1:20
#		println("adaptive ref step $i")
#		# call generate_next_level! with tol=1e-5 and maxlevels=20
#		cpts = generate_next_level!(asg, tol, 20)
#		if isempty(cpts)
#			break
#		end
#		init_weights_inplace_ops!(asg, collect(cpts), _fun)
#		println("$(length(cpts)) new cpts")
#	end
#	return asg
#end
