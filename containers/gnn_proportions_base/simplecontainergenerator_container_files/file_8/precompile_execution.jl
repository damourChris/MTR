import CSV # pkg_names_to_import
import CategoricalArrays # pkg_names_to_import
import Comonicon # pkg_names_to_import
import DataFrames # pkg_names_to_import
import DotEnv # pkg_names_to_import
import EnumX # pkg_names_to_import
import ExpressionData # pkg_names_to_import
import Flux # pkg_names_to_import
import GraphNeuralNetworks # pkg_names_to_import
import GraphRecipes # pkg_names_to_import
import Graphs # pkg_names_to_import
import HTTP # pkg_names_to_import
import JLD2 # pkg_names_to_import
import JSON # pkg_names_to_import
import LightXML # pkg_names_to_import
import MLUtils # pkg_names_to_import
import MetaGraphs # pkg_names_to_import
import OntologyLookup # pkg_names_to_import
import OpenSSL # pkg_names_to_import
import Plots # pkg_names_to_import
import Preferences # pkg_names_to_import
import ProgressMeter # pkg_names_to_import
import RCall # pkg_names_to_import
import RDatasets # pkg_names_to_import
import Requires # pkg_names_to_import
import STRINGdb # pkg_names_to_import
import TSne # pkg_names_to_import
import YAML # pkg_names_to_import

import Pkg
for (uuid, info) in Pkg.dependencies()
if info.name in ["CSV", "CategoricalArrays", "Comonicon", "DataFrames", "DotEnv", "EnumX", "ExpressionData", "Flux", "GraphNeuralNetworks", "GraphRecipes", "Graphs", "HTTP", "JLD2", "JSON", "LightXML", "MLUtils", "MetaGraphs", "OntologyLookup", "OpenSSL", "Plots", "Preferences", "ProgressMeter", "RCall", "RDatasets", "Requires", "STRINGdb", "TSne", "YAML"] # pkg_names_to_test
ENV["PREDICTMD_TEST_PLOTS"] = "true"
ENV["PREDICTMD_TEST_GROUP"] = "all"

include(joinpath(info.source, "test", "runtests.jl"))
end
end

