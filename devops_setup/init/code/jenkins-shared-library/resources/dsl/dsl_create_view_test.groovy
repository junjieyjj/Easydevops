/* 从参数获取jobs */
Map jobs_map = props['jobs_map']

println("in dsl_create_view.groovy: " + jobs_map)

jobs_map.each {
    // 创建以group命名的view，并把group下的job加入该view
    group = it.key
    println group
    listView(group) {
        description("${group}项目的cicd流水线")
        recurse()
        jobs {
            regex("^${group}/.*/(ci|cd|config|secret)_.*")
        }
        columns {
            status()
            weather()
            name()
            lastSuccess()
            lastFailure()
            lastDuration()
            buildButton()
        }
    }
}