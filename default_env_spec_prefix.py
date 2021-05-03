from anaconda_project.project import Project

project = Project('.')
name = project.default_env_spec_name
prefix = project.env_specs[name].path('.')
print(prefix)
