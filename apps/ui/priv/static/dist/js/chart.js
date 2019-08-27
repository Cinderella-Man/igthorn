window.renderChart = (labels, symbol, data) => {
    if(["complete", "loaded", "interactive"].indexOf(document.readyState) >= 0){
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
    if(["complete", "loaded", "interactive"].indexOf(document.readyState) >= 0){
        doDoughnutChartRender(labels, symbol, data)
    } else {
        document.addEventListener("DOMContentLoaded", () => doDoughnutChartRender(labels, symbol, data))
    }
};

let doDoughnutChartRender = (labels, symbol, data) => {
    let chartData = {
        datasets: [{
            data: data,
            backgroundColor: [
                '#00a65a',
                '#dd4b39'
            ],
        }],
        labels: labels
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
