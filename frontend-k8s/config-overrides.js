const { override } = require('customize-cra');

const version = process.env.appVersion;
const staticResourcesPrefix = process.env.appResourcesPrefix;
const cdnHost = process.env.cdnHost;

const setPublicPath = value => config => {
    // mutate config as you want
    config.output.publicPath = value
  
    // return config so the next function in the pipeline receives it as argument
    return config;
 }

 const enableideoLoader = () => config => {
    config.module.rules.push({
        test: /\.mp4$/,
        use: 'file-loader?name=videos/[name].[ext]',
    })
    return config;
 }

module.exports = override(
    setPublicPath(`${cdnHost}${staticResourcesPrefix}/${version}/`),
    enableideoLoader()
);