window.renderChart = (labels, symbol, data) => {
    if (["complete", "loaded", "interactive"].indexOf(document.readyState) >= 0) {
        doRender(labels, symbol, data)
    } else {
        document.addEventListener("DOMContentLoaded", () => doRender(labels, symbol, data))
    }
};

let doRender = (labels, symbol, data) => {

    var chartData = {
        labels: labels,
        datasets: [{
            label: symbol,
            backgroundColor: 'rgba(255, 99, 132, 0.1)',
            borderColor: 'rgb(255, 99, 132)',
            data: data,
            fill: 'origin',
            lineTension: 0
        }]
    };

    var config = {
        type: 'line',
        data: chartData,
        options: {
            animation: false,
            responsive: false,
            tooltips: {
                mode: 'index',
                intersect: false,
            },
            scales: {
                xAxes: [{
                    display: true,
                    scaleLabel: {
                        display: true,
                        labelString: 'Time'
                    }
                }],
                yAxes: [{
                    display: true,
                    scaleLabel: {
                        display: true,
                        labelString: 'Price'
                    }
                }]
            },
            legend: {
                display: true,
                labels: {
                    fontColor: 'rgb(255, 99, 132)'
                }
            }
        }
    };

    if (window.chart !== undefined) {
        window.chart.data = chartData;
        window.chart.update();
        return;
    }

    var ctx = document.getElementById('lineChart');
    window.chart = new Chart(ctx, config);
};

window.renderDoughnutChart = (labels, symbol, data) => {
    if (["complete", "loaded", "interactive"].indexOf(document.readyState) >= 0) {
        doDoughnutChartRender(labels, symbol, data)
    } else {
        document.addEventListener("DOMContentLoaded", () => doDoughnutChartRender(labels, symbol, data))
    }
};

let doDoughnutChartRender = (data) => {
    let chartData = {
        datasets: [{
            data: data,
            backgroundColor: [
                '#00a65a',
                '#dd4b39'
            ],
        }],
        labels: data
    };
    let chartConfig = {
        type: 'doughnut',
        data: chartData,
        options: {}
    };

    if (window.donatChart !== undefined) {
        window.donatChart.data = chartData;
        window.donatChart.update();
        return;
    }

    var ctx = document.getElementById('doughnutChart');
    window.donatChart = new Chart(ctx, chartConfig);
};

window.renderBarChart = (symbols, values) => {
    if (["complete", "loaded", "interactive"].indexOf(document.readyState) >= 0) {
         doBarChartRender(symbols, values)
    } else {
        document.addEventListener("DOMContentLoaded", () => doBarChartRender(symbols, values))
    }
};

let doBarChartRender = (symbols, data) => {

    let datasets = [];
    let max = [];
    symbols.forEach((symbol, index) => {
        let val = [];
        data.values.forEach((values) => {
            if (values[symbol]) {
                val = values[symbol]
            }
        });

        if (max.length === 0) {
            max = val
        } else {
            max = val.map(function (num, idx) {
                return num + max[idx];
            })
        }

        datasets.push({
            label: symbol,
            data: val,
            backgroundColor: chartBackgroundColors[index],
            borderColor: chartColors[index],
            borderWidth: 1
        })
    });

    let chartData = {
        datasets: datasets,
        labels: data.labels
    };

    let chartConfig = {
        type: 'bar',
        data: chartData,
        options: {
            animation: false,
            responsive: false,
            tooltips: {
                mode: 'index',
                intersect: false,
            },
            scales: {
                xAxes: [{
                    stacked: true,
                    display: true,
                    scaleLabel: {
                        display: true,
                        labelString: 'Date'
                    },
                }],
                yAxes: [{
                    stacked: true,
                    display: true,
                    scaleLabel: {
                        display: true,
                        labelString: 'Trades'
                    },
                    ticks: {
                        suggestedMin: 0,
                        suggestedMax: Math.max.apply(null, max) + 1,
                    }
                }]
            },
        }
    };

    if (window.colunmChart !== undefined) {
        window.colunmChart.data = chartData;
        window.colunmChart.update();
        return;
    }

    var ctx = document.getElementById('barChart');
    window.colunmChart = new Chart(ctx, chartConfig);
}

let chartColors = [
    'rgb(255, 99, 132)',
    'rgb(255, 159, 64)',
    'rgb(255, 205, 86)',
    'rgb(75, 192, 192)',
    'rgb(54, 162, 235)',
    'rgb(153, 102, 255)',
    'rgb(201, 203, 207)'
]

let chartBackgroundColors = [
    'rgba(255, 99, 132, 0.5)',
    'rgba(255, 159, 64, 0.5)',
    'rgba(255, 205, 86, 0.5)',
    'rgba(75, 192, 192, 0.5)',
    'rgba(54, 162, 235, 0.5)',
    'rgba(153, 102, 255, 0.5)',
    'rgba(201, 203, 207, 0.5)'
]